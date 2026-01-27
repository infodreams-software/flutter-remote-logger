/// Base class for all remote logger events
abstract class RemoteLoggerEvent {}

/// Emitted when an upload operation completes successfully
class RemoteLoggerSuccess extends RemoteLoggerEvent {
  final String message;
  final String? fileUrl;

  RemoteLoggerSuccess(this.message, {this.fileUrl});
}

/// Emitted when an error occurs within the RemoteLogger
class RemoteLoggerError extends RemoteLoggerEvent {
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  RemoteLoggerError(this.message, {this.error, this.stackTrace});

  @override
  String toString() => 'RemoteLoggerError: $message, error: $error';
}
