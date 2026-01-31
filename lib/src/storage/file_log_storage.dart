import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/log_entry.dart';
import 'log_storage.dart';

/// A [LogStorage] implementation that writes logs to the local file system.
///
/// Logs are stored in the application documents directory under a `logs` subdirectory.
/// Filenames include the session ID and a `.flutter.jsonl` suffix.
class FileLogStorage implements LogStorage {
  File? _currentFile;

  /// Creates a new [FileLogStorage] instance.
  FileLogStorage();

  @override
  /// Initializes the storage for a specific session.
  ///
  /// [sessionId] is the unique identifier for the current session.
  /// [groupSessionId] is an optional identifier to group multiple sessions (e.g. across platforms).
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
  /// Writes a [LogEntry] to the current log file as a JSON line.
  Future<void> write(LogEntry entry) async {
    if (_currentFile == null) return;
    final jsonLine = jsonEncode(entry.toJson());
    await _currentFile!.writeAsString('$jsonLine\n', mode: FileMode.append);
  }

  @override
  void writeSync(LogEntry entry) {
    if (_currentFile == null) return;
    final jsonLine = jsonEncode(entry.toJson());
    _currentFile!.writeAsStringSync('$jsonLine\n', mode: FileMode.append);
  }

  @override
  /// Returns the current session's log file, if initialized.
  Future<File?> getSessionFile() async {
    return _currentFile;
  }

  @override
  /// Retrieves a list of log files from previous sessions.
  ///
  /// Excludes the file corresponding to [currentSessionId].
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
