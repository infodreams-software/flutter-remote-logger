import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/log_entry.dart';
import 'log_storage.dart';

class FileLogStorage implements LogStorage {
  File? _currentFile;

  @override
  Future<void> initialize(String sessionId, {String? groupSessionId}) async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final suffix = groupSessionId != null ? '_$groupSessionId' : '';
    _currentFile = File('${logDir.path}/log_$sessionId$suffix.flutter.jsonl');
  }

  @override
  Future<void> write(LogEntry entry) async {
    if (_currentFile == null) return;
    final jsonLine = jsonEncode(entry.toJson());
    await _currentFile!.writeAsString('$jsonLine\n', mode: FileMode.append);
  }

  @override
  Future<File?> getSessionFile() async {
    return _currentFile;
  }

  @override
  Future<List<File>> getOldSessionFiles(String currentSessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/logs');
    if (!await logDir.exists()) {
      return [];
    }

    final allFiles = logDir.listSync().whereType<File>().toList();
    // Assuming file pattern: log_$sessionId.flutter.jsonl
    return allFiles.where((file) {
      final name = file.path.split('/').last;
      // Filter out non-logs or current session log
      return name.startsWith('log_') &&
          name.endsWith('.flutter.jsonl') &&
          !name.contains(currentSessionId);
    }).toList();
  }
}
