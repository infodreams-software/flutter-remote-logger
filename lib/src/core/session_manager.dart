import 'package:uuid/uuid.dart';

class SessionManager {
  final _uuid = const Uuid();
  late final String _currentSessionId;
  final int _startTime;

  SessionManager() : _startTime = DateTime.now().millisecondsSinceEpoch {
    _currentSessionId = _uuid.v4();
  }

  String get sessionId => _currentSessionId;
  int get startTime => _startTime;
}
