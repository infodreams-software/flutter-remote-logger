import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Synchronizes session IDs across platforms (Flutter/Android) using a shared lock file.
class SessionSynchronizer {
  static const String _lockFileName = 'session.lock';

  /// Returns a synchronized session ID.
  ///
  /// Algorithm:
  /// 1. Check if `session.lock` exists in app supported documents directory.
  /// 2. Read content (Format: "PID:SESSION_ID").
  /// 3. If file PID matches current process PID, return SESSION_ID.
  /// 4. Else, generate new ID, overwrite file with "PID:NEW_ID", and return new ID.
  ///
  /// Note: [getApplicationSupportDirectory] maps to `context.filesDir` on Android,
  /// matching the path used by the native library.
  Future<String> getOrGenerateSessionId() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final lockFile = File('${dir.path}/$_lockFileName');
      final currentPid = pid; // dart:io pid returns current process ID

      if (await lockFile.exists()) {
        try {
          final content = await lockFile.readAsString();
          final parts = content.trim().split(':');

          if (parts.length == 2) {
            final filePid = int.tryParse(parts[0]);
            final sessionId = parts[1];

            if (filePid == currentPid && sessionId.isNotEmpty) {
              // Reuse session if PID matches
              return sessionId;
            }
          }
        } catch (e) {
          // Ignore read/parse errors
        }
      }

      // Generate new ID if file doesn't exist or is stale/PID mismatch
      final newId = const Uuid().v4();
      await lockFile.writeAsString('$currentPid:$newId');
      return newId;
    } catch (e) {
      // Fallback in case of IO errors
      return const Uuid().v4();
    }
  }
}
