import 'dart:io';
import '../models/log_entry.dart';

abstract class LogStorage {
  Future<void> initialize(String sessionId);
  Future<void> write(LogEntry entry);
  Future<File?> getSessionFile();
  Future<List<File>> getOldSessionFiles(String currentSessionId);
}
