import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class SessionSynchronizer {
  static const String _lockFileName = 'session.lock';
  static const Duration _freshnessThreshold = Duration(seconds: 5);

  /// Returns the synchronized session ID.
  ///
  /// Algorithm:
  /// 1. Check if `session.lock` exists in app documents.
  /// 2. If valid (modified < 5s ago), read and return ID.
  /// 3. Else, generate new ID, overwrite file, and return new ID.
  Future<String> getOrGenerateSessionId() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final lockFile = File('${dir.path}/$_lockFileName');

      if (await lockFile.exists()) {
        final lastModified = await lockFile.lastModified();
        final now = DateTime.now();
        final difference = now.difference(lastModified).abs();

        if (difference < _freshnessThreshold) {
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
      // Fallback in case of IO error
      return const Uuid().v4();
    }
  }
}
