import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/session_info.dart';
import 'log_uploader.dart';

/// An implementation of [LogUploader] that uploads logs and data to Supabase.
///
/// It requires a configured [SupabaseClient].
///
/// **Supabase Setup:**
/// Ensure you have the following tables in your Supabase database:
/// - `remote_log_sessions` (stores session metadata)
/// - `remote_log_device_links` (stores device-user association)
/// And a storage bucket named `remote_logs` (or your custom bucket name).
class SupabaseLogUploader implements LogUploader {
  final SupabaseClient _supabase;
  final String _storageBucket;
  final String _sessionsTable;
  final String _deviceLinksTable;

  /// Creates a generic Supabase uploader.
  ///
  /// [supabaseClient] is your initialized Supabase client.
  /// [bucketName] defaults to 'remote_logs'.
  /// [sessionsTable] defaults to 'remote_log_sessions'.
  /// [deviceLinksTable] defaults to 'remote_log_device_links'.
  SupabaseLogUploader({
    required SupabaseClient supabaseClient,
    String bucketName = 'remote_logs',
    String sessionsTable = 'remote_log_sessions',
    String deviceLinksTable = 'remote_log_device_links',
  }) : _supabase = supabaseClient,
       _storageBucket = bucketName,
       _sessionsTable = sessionsTable,
       _deviceLinksTable = deviceLinksTable;

  @override
  Future<void> uploadSession(File logFile, SessionInfo sessionInfo) async {
    final fileName = '${sessionInfo.deviceId}/${sessionInfo.sessionId}.jsonl';

    // 1. Upload file to Storage
    await _supabase.storage
        .from(_storageBucket)
        .upload(
          fileName,
          logFile,
          fileOptions: const FileOptions(upsert: true),
        );

    final logFileUrl = _supabase.storage
        .from(_storageBucket)
        .getPublicUrl(fileName);

    // 2. Insert metadata into Table
    // Extract details from deviceMetadata map
    final metadata = sessionInfo.deviceMetadata;

    // Convert int timestamp (ms) to ISO8601
    final startTimeIso = DateTime.fromMillisecondsSinceEpoch(
      sessionInfo.startTime,
    ).toIso8601String();

    final row = {
      'session_id': sessionInfo.sessionId,
      'device_id': sessionInfo.deviceId,
      'start_time': startTimeIso,
      // 'end_time': null, // SessionInfo doesn't track end time explicitly yet
      'app_version': metadata['appVersion'],
      'os_version': metadata['osVersion'],
      'device_model': metadata['deviceModel'],
      'user_id': sessionInfo.userId,
      'custom_data': metadata, // Store full metadata as jsonb
      'log_file_url': logFileUrl,
      'uploaded_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from(_sessionsTable).upsert(row);
  }

  @override
  Future<void> identifyUser(String deviceId, String userId) async {
    // 1. Record the device-user link
    await _supabase.from(_deviceLinksTable).insert({
      'device_id': deviceId,
      'user_id': userId,
      'linked_at': DateTime.now().toIso8601String(),
    });

    // 2. Best-effort: Update past sessions for this device that have no user_id
    // supabase_flutter v2 uses filter modifiers like .eq, .isFilter
    // for 'is null' validation checks.

    await _supabase
        .from(_sessionsTable)
        .update({'user_id': userId})
        .match({'device_id': deviceId})
        .filter('user_id', 'is', null);
  }

  @override
  Future<void> uploadDeviceInfo(
    String deviceId,
    Map<String, dynamic> deviceInfo,
  ) async {
    final fileName = '$deviceId/device_info.json';
    final jsonString = jsonEncode(deviceInfo);

    // Supabase storage 'uploadBinary' takes Uint8List
    final bytes = utf8.encode(jsonString);

    await _supabase.storage
        .from(_storageBucket)
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'application/json',
          ),
        );
  }
}
