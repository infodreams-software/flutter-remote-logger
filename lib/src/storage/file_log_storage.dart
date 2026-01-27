import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/log_entry.dart';
import 'log_storage.dart';

class FileLogStorage implements LogStorage {
  File? _currentFile;

  @override
  Future<void> initialize(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _currentFile = File('${logDir.path}/log_$sessionId.jsonl');
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
}
