import 'dart:async';
import 'package:flutter/foundation.dart';

import 'device_info.dart';
import 'session_manager.dart';
import '../models/log_entry.dart';
import '../models/session_info.dart';
import '../storage/log_storage.dart';
import '../storage/file_log_storage.dart';
import '../uploader/log_uploader.dart';
import '../uploader/firebase_uploader.dart';

class RemoteLogger {
  static final RemoteLogger _instance = RemoteLogger._internal();

  factory RemoteLogger() => _instance;

  RemoteLogger._internal();

  LogStorage? _storage;
  LogUploader? _uploader;
  SessionManager? _sessionManager;
  DeviceInfoProvider? _deviceInfoProvider;

  SessionInfo? _currentSession;
  bool _isInitialized = false;

  Timer? _uploadTimer;

  /// Initialize the logger.
  /// [storage] defaults to [FileLogStorage].
  /// [uploader] defaults to [FirebaseLogUploader].
  /// [sessionManager] and [deviceInfoProvider] can be injected for testing.
  /// [autoUploadFrequency] if provided, triggers periodic uploads of the current session.
  Future<void> initialize({
    LogStorage? storage,
    LogUploader? uploader,
    SessionManager? sessionManager,
    DeviceInfoProvider? deviceInfoProvider,
    Duration? autoUploadFrequency,
  }) async {
    if (_isInitialized) return;

    _storage = storage ?? FileLogStorage();
    _uploader = uploader ?? FirebaseLogUploader();
    _sessionManager = sessionManager ?? SessionManager();
    _deviceInfoProvider = deviceInfoProvider ?? DeviceInfoProvider();

    // Gather session info
    final deviceMetadata = await _deviceInfoProvider!.getDeviceMetadata();
    final deviceId = await _deviceInfoProvider!.getDeviceId();

    _currentSession = SessionInfo(
      sessionId: _sessionManager!.sessionId,
      deviceId: deviceId,
      startTime: _sessionManager!.startTime,
      deviceMetadata: deviceMetadata,
    );

    await _storage!.initialize(_currentSession!.sessionId);

    // 1. Recover and upload old sessions (fire and forget)
    _processOldSessions();

    // 2. Start auto-upload timer if requested
    if (autoUploadFrequency != null) {
      _uploadTimer = Timer.periodic(autoUploadFrequency, (_) {
        uploadCurrentSession();
      });
    }

    _isInitialized = true;

    // Log internal start
    log('RemoteLogger initialized. Session: ${_currentSession!.sessionId}');
  }

  Future<void> _processOldSessions() async {
    if (_storage == null || _uploader == null || _currentSession == null)
      return;

    try {
      final oldFiles = await _storage!.getOldSessionFiles(
        _currentSession!.sessionId,
      );
      for (final file in oldFiles) {
        log(
          'Uploading found orphan session: ${file.path}',
          tag: 'REMOTE_LOGGER',
        );

        // Extract session ID from filename: log_UUID.jsonl
        final filename = file.path.split('/').last;
        final sessionId = filename
            .replaceAll('log_', '')
            .replaceAll('.jsonl', '');

        // Reconstruct a best-effort SessionInfo
        // Note: we use current device metadata as we assume it hasn't changed.
        // Ideally we would read this from the file header if we stored it there.
        final recoveredSession = SessionInfo(
          sessionId: sessionId,
          deviceId: _currentSession!.deviceId,
          startTime:
              0, // Unknown start time for rescued files unless we parse filename/metadata
          deviceMetadata: _currentSession!.deviceMetadata,
          userId: _currentSession!
              .userId, // Unknown, defaulting to none or current? safer to keep null/current
        );

        await _uploader!.uploadSession(file, recoveredSession);

        // Delete after successful upload to avoid re-uploading
        await file.delete();
      }
    } catch (e) {
      log(
        'Failed to process old sessions: $e',
        level: 'ERROR',
        tag: 'REMOTE_LOGGER',
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
    if (!_isInitialized) {
      debugPrint('RemoteLogger not initialized. Dropping log: $message');
      return;
    }

    final entry = LogEntry(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      level: level,
      tag: tag,
      message: message,
      payload: payload,
    );

    await _storage!.write(entry);
  }

  /// Force upload of the current session logs.
  Future<void> uploadCurrentSession() async {
    if (!_isInitialized || _currentSession == null) return;

    final file = await _storage!.getSessionFile();
    if (file != null && await file.exists()) {
      try {
        await _uploader!.uploadSession(file, _currentSession!);
        log('Session uploaded successfully', tag: 'REMOTE_LOGGER');
      } catch (e) {
        log(
          'Failed to upload session: $e',
          level: 'ERROR',
          tag: 'REMOTE_LOGGER',
        );
      }
    }
  }

  /// Link the current device to a specific user.
  Future<void> identifyUser(String userId) async {
    if (!_isInitialized || _currentSession == null) return;

    try {
      // 1. Send linking info to remote
      await _uploader!.identifyUser(_currentSession!.deviceId, userId);

      // 2. Update local session info (for future uploads in this session)
      _currentSession = SessionInfo(
        sessionId: _currentSession!.sessionId,
        deviceId: _currentSession!.deviceId,
        startTime: _currentSession!.startTime,
        deviceMetadata: _currentSession!.deviceMetadata,
        userId: userId,
      );

      log('User identified: $userId', tag: 'REMOTE_LOGGER');
    } catch (e) {
      log('Failed to identify user: $e', level: 'ERROR', tag: 'REMOTE_LOGGER');
    }
  }

  @visibleForTesting
  void reset() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    _isInitialized = false;
    _currentSession = null;
    _storage = null;
    _uploader = null;
    _sessionManager = null;
    _deviceInfoProvider = null;
  }
}
