import 'dart:io';
import '../models/session_info.dart';

abstract class LogUploader {
  Future<void> uploadSession(
    File logFile,
    SessionInfo sessionInfo, {
    String? path,
  });
  Future<void> identifyUser(String deviceId, String userId);
  Future<void> uploadDeviceInfo(
    String deviceId,
    Map<String, dynamic> deviceInfo, {
    String? path,
  });
}
