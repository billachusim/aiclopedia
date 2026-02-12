class AIException implements Exception {
  final String message;

  AIException(this.message);

  @override
  String toString() => message;
}

class AITimeoutException extends AIException {
  AITimeoutException() : super("AI took too long to respond.");
}

class AIModelUnavailableException extends AIException {
  AIModelUnavailableException()
      : super("AI model is currently unavailable.");
}
