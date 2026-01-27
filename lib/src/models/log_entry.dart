class LogEntry {
  final int timestamp;
  final String time;
  final String level;
  final String tag;
  final String message;
  final Map<String, dynamic>? payload;

  LogEntry({
    required this.timestamp,
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.payload,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'time': time,
      'level': level,
      'tag': tag,
      'message': message,
      if (payload != null) 'payload': payload,
    };
  }
}
