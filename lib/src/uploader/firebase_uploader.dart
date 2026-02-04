import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_info.dart';
import 'log_uploader.dart';

class FirebaseLogUploader implements LogUploader {
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  FirebaseLogUploader({FirebaseStorage? storage, FirebaseFirestore? firestore})
    : _storage = storage ?? FirebaseStorage.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> uploadSession(
    File logFile,
    SessionInfo sessionInfo, {
    String? path,
  }) async {
    // If path is provided, use it. If not, default to 'logs/'.
    // Wait, the original code used 'logs/'. If path is custom, should I overwrite 'logs/' or append?
    // "logs/" seems to be a hardcoded base. The user "project/version" probably wants to replace or prepend.
    // Let's assume user path replaces "logs/" or user path IS the base.
    // If path is "project/v1", result: "project/v1/deviceId/..."
    // original: "logs/deviceId/..."

    final basePath = path != null ? path : 'logs';

    final ref = _storage.ref().child(
      '$basePath/${sessionInfo.deviceId}/${sessionInfo.sessionId}.jsonl',
    );

    // Upload file
    await ref.putFile(logFile);
    final downloadUrl = await ref.getDownloadURL();

    // Save metadata to Firestore
    final data = sessionInfo.toJson();
    data['logFileUrl'] = downloadUrl;
    data['uploadedAt'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('sessions')
        .doc(sessionInfo.sessionId)
        .set(data);
  }

  @override
  Future<void> identifyUser(String deviceId, String userId) async {
    // 1. Record the link in a dedicated collection for searching
    await _firestore.collection('user_device_links').add({
      'deviceId': deviceId,
      'userId': userId,
      'linkedAt': FieldValue.serverTimestamp(),
    });

    // 2. Best-effort update of the last 10 sessions for this device.
    try {
      final recentSessions = await _firestore
          .collection('sessions')
          .where('deviceId', isEqualTo: deviceId)
          .where('userId', isNull: true)
          .orderBy('startTime', descending: true)
          .limit(10)
          .get();

      final batch = _firestore.batch();
      for (var doc in recentSessions.docs) {
        batch.update(doc.reference, {'userId': userId});
      }
      await batch.commit();
    } catch (e) {
      // Ignore errors here
    }
  }

  @override
  Future<void> uploadDeviceInfo(
    String deviceId,
    Map<String, dynamic> deviceInfo, {
    String? path,
  }) async {
    final basePath = path != null ? path : 'logs';
    final ref = _storage.ref().child('$basePath/$deviceId/device_info.json');
    await ref.putString(jsonEncode(deviceInfo));
  }
}
