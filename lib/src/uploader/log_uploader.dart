import 'dart:io';
import '../models/session_info.dart';

abstract class LogUploader {
  Future<void> uploadSession(File logFile, SessionInfo sessionInfo);
  Future<void> identifyUser(String deviceId, String userId);
}
