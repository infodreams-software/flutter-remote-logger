import 'dart:async';
import 'package:flutter/foundation.dart';

import 'device_info.dart';
import 'session_manager.dart';
import 'session_synchronizer.dart';
import '../models/log_entry.dart';
import '../models/session_info.dart';
import '../storage/log_storage.dart';
import '../storage/file_log_storage.dart';
import '../uploader/log_uploader.dart';
import '../models/remote_logger_event.dart';
import '../uploader/firebase_uploader.dart';

class RemoteLogger {
  /// The singleton instance of [RemoteLogger].
  static final RemoteLogger _instance = RemoteLogger._internal();

  /// Returns the singleton instance.
  factory RemoteLogger() => _instance;

  RemoteLogger._internal();

  LogStorage? _storage;
  LogUploader? _uploader;
  SessionManager? _sessionManager;
  DeviceInfoProvider? _deviceInfoProvider;

  SessionInfo? _currentSession;
  bool _isInitialized = false;
  bool _isEnabled = true;

  final StreamController<RemoteLoggerEvent> _eventController =
      StreamController<RemoteLoggerEvent>.broadcast();

  /// Stream of events (errors, success) from the logger.
  Stream<RemoteLoggerEvent> get events => _eventController.stream;

  /// Get the current device ID. Returns null if not initialized.
  String? get deviceId => _currentSession?.deviceId;

  Timer? _uploadTimer;

  /// Initialize the logger.
  /// [storage] defaults to [FileLogStorage].
  /// [uploader] defaults to [FirebaseLogUploader].
  /// [sessionManager] and [deviceInfoProvider] can be injected for testing.
  /// [autoUploadFrequency] if provided, triggers periodic uploads of the current session.
  /// [isEnabled] defaults to true. If false, logging and uploading are disabled.
  Future<void> initialize({
    LogStorage? storage,
    LogUploader? uploader,
    SessionManager? sessionManager,
    DeviceInfoProvider? deviceInfoProvider,
    Duration? autoUploadFrequency,
    bool isEnabled = true,
    String? groupSessionId,
  }) async {
    if (_isInitialized) {
      return;
    }

    _isEnabled = isEnabled;
    if (!_isEnabled) {
      log('RemoteLogger disabled.', level: 'INFO', tag: 'REMOTE_LOGGER');
      _isInitialized = true;
      return;
    }

    _storage = storage ?? FileLogStorage();
    _uploader = uploader ?? FirebaseLogUploader();
    _sessionManager = sessionManager ?? SessionManager();
    _deviceInfoProvider = deviceInfoProvider ?? DeviceInfoProvider();

    // Determine groupSessionId
    String? finalGroupId = groupSessionId;
    if (finalGroupId == null) {
      // If no group ID provided, try to synchronize with other platforms
      // This is a "best effort" synchronization
      try {
        final synchronizer = SessionSynchronizer();
        finalGroupId = await synchronizer.getOrGenerateSessionId();
      } catch (e) {
        debugPrint('Failed to synchronize session: $e');
        // If sync fails, proceed without group ID (or we could generate one locally)
        // But the requirement implies we want coupling.
        // If sync fails, we might just degenerate to no-group
      }
    }

    // Gather session info
    try {
      final deviceMetadata = await _deviceInfoProvider!.getDeviceMetadata();
      final deviceId = await _deviceInfoProvider!.getDeviceId();

      _currentSession = SessionInfo(
        sessionId: _sessionManager!.sessionId,
        deviceId: deviceId,
        startTime: _sessionManager!.startTime,

        deviceMetadata: deviceMetadata,
        groupSessionId: finalGroupId,
      );

      await _storage!.initialize(
        _currentSession!.sessionId,
        groupSessionId: finalGroupId,
      );

      // Upload general device info file for easier identification
      // ... rest of the method unchanged
      try {
        await _uploader!.uploadDeviceInfo(deviceId, deviceMetadata);
      } catch (e) {
        log('Failed to upload device info: $e', level: 'WARNING');
      }

      _processOldSessions();

      if (autoUploadFrequency != null) {
        _uploadTimer = Timer.periodic(autoUploadFrequency, (_) {
          uploadCurrentSession();
        });
      }

      _isInitialized = true;
      log('RemoteLogger initialized. Session: ${_currentSession!.sessionId}');
    } catch (e, stack) {
      debugPrint('RemoteLogger initialization failed: $e');
      _eventController.add(
        RemoteLoggerError('Initialization failed', error: e, stackTrace: stack),
      );
    }
  }

  Future<void> _processOldSessions() async {
    if (!_isEnabled ||
        _storage == null ||
        _uploader == null ||
        _currentSession == null) {
      return;
    }

    try {
      final oldFiles = await _storage!.getOldSessionFiles(
        _currentSession!.sessionId,
      );
      for (final file in oldFiles) {
        log(
          'Uploading found orphan session: ${file.path}',
          tag: 'REMOTE_LOGGER',
        );

        final filename = file.path.split('/').last;
        final sessionId = filename
            .replaceAll('log_', '')
            .replaceAll(
              RegExp(r'(_.*)?\.flutter\.jsonl'),
              '',
            ) // Remove suffix and group ID if present
            .replaceAll('.jsonl', ''); // Fallback for old files

        final recoveredSession = SessionInfo(
          sessionId: sessionId,
          deviceId: _currentSession!.deviceId,
          startTime: 0,
          deviceMetadata: _currentSession!.deviceMetadata,
          userId: _currentSession!.userId,
        );

        await _uploader!.uploadSession(file, recoveredSession);

        // Delete after successful upload to avoid re-uploading
        await file.delete();

        _eventController.add(
          RemoteLoggerSuccess('Orphan session uploaded: $sessionId'),
        );
      }
    } catch (e, stack) {
      log(
        'Failed to process old sessions: $e',
        level: 'ERROR',
        tag: 'REMOTE_LOGGER',
      );
      _eventController.add(
        RemoteLoggerError(
          'Failed to process old sessions',
          error: e,
          stackTrace: stack,
        ),
      );
    }
  }

  /// Log a message.
  Future<void> log(
    String message, {
    String level = 'INFO',
    String tag = 'APP',
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized || !_isEnabled) {
      if (!_isEnabled && _isInitialized) {
        return; // Silent return if explicitly disabled
      }
      debugPrint('RemoteLogger not initialized. Dropping log: $message');
      return;
    }

    final now = DateTime.now();
    final entry = LogEntry(
      timestamp: now.millisecondsSinceEpoch,
      time: now.toIso8601String(),
      level: level,
      tag: tag,
      message: message,
      payload: payload,
    );

    await _storage!.write(entry);
  }

  /// Force upload of the current session logs.
  Future<void> uploadCurrentSession() async {
    if (!_isInitialized || !_isEnabled || _currentSession == null) {
      return;
    }

    final file = await _storage!.getSessionFile();
    if (file != null && await file.exists()) {
      try {
        await _uploader!.uploadSession(file, _currentSession!);
        log('Session uploaded successfully', tag: 'REMOTE_LOGGER');
        _eventController.add(
          RemoteLoggerSuccess(
            'Session uploaded successfully',
            fileUrl: file.path,
          ),
        );
      } catch (e, stack) {
        log(
          'Failed to upload session: $e',
          level: 'ERROR',
          tag: 'REMOTE_LOGGER',
        );
        _eventController.add(
          RemoteLoggerError(
            'Failed to upload session',
            error: e,
            stackTrace: stack,
          ),
        );
      }
    }
  }

  /// Link the current device to a specific user.
  Future<void> identifyUser(String userId) async {
    if (!_isInitialized || !_isEnabled || _currentSession == null) {
      return;
    }

    try {
      await _uploader!.identifyUser(_currentSession!.deviceId, userId);

      _currentSession = SessionInfo(
        sessionId: _currentSession!.sessionId,
        deviceId: _currentSession!.deviceId,
        startTime: _currentSession!.startTime,
        deviceMetadata: _currentSession!.deviceMetadata,
        userId: userId,
      );

      log('User identified: $userId', tag: 'REMOTE_LOGGER');
      _eventController.add(RemoteLoggerSuccess('User identified: $userId'));
    } catch (e, stack) {
      log('Failed to identify user: $e', level: 'ERROR', tag: 'REMOTE_LOGGER');
      _eventController.add(
        RemoteLoggerError(
          'Failed to identify user',
          error: e,
          stackTrace: stack,
        ),
      );
    }
  }

  @visibleForTesting
  void reset() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    // Don't close _eventController here as it's broadcast and intended to live with the app singleton
    // But we might want to if simulating full shutdown.
    // Since it's a singleton, usually streams stay open.
    _isInitialized = false;
    _currentSession = null;
    _storage = null;
    _uploader = null;
    _sessionManager = null;
    _deviceInfoProvider = null;
  }
}
