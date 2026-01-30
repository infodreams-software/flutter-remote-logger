import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Synchronizes session IDs across platforms (Flutter/Android) using a shared lock file.
class SessionSynchronizer {
  static const String _lockFileName = 'session.lock';
  static const int _freshnessThresholdMs = 5000; // 5 seconds

  /// Returns a synchronized session ID.
  ///
  /// Algorithm:
  /// 1. Check if `session.lock` exists in app supported documents directory.
  /// 2. If valid (modified < 5s ago), read and return ID.
  /// 3. Else, generate new ID, overwrite file, and return new ID.
  ///
  /// Note: [getApplicationSupportDirectory] maps to `context.filesDir` on Android,
  /// matching the path used by the native library.
  Future<String> getOrGenerateSessionId() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final lockFile = File('${dir.path}/$_lockFileName');

      if (await lockFile.exists()) {
        final lastModified = await lockFile.lastModified();
        final now = DateTime.now();
        final difference = now.difference(lastModified).inMilliseconds.abs();

        if (difference < _freshnessThresholdMs) {
          final content = await lockFile.readAsString();
          final id = content.trim();
          if (id.isNotEmpty) {
            return id;
          }
        }
      }

      // Generate new ID if file doesn't exist or is stale
      final newId = const Uuid().v4();
      await lockFile.writeAsString(newId);
      return newId;
    } catch (e) {
      // Fallback in case of IO errors
      return const Uuid().v4();
    }
  }
}
