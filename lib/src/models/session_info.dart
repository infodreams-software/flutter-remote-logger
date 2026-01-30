class SessionInfo {
  final String sessionId;
  final String deviceId;
  final int startTime;
  final String? userId; // Nullable, can be linked later
  final String? groupSessionId;
  final Map<String, dynamic> deviceMetadata;

  SessionInfo({
    required this.sessionId,
    required this.deviceId,
    required this.startTime,
    this.userId,
    this.groupSessionId,
    this.deviceMetadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'deviceId': deviceId,
      'startTime': startTime,
      'userId': userId,
      'groupSessionId': groupSessionId,
      'deviceMetadata': deviceMetadata,
    };
  }
}
