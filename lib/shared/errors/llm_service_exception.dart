enum LlmServiceErrorCode {
  notInitialized,
  initializationFailed,
  generationFailed,
  notImplemented,
}

class LlmServiceException implements Exception {
  const LlmServiceException(this.code, this.message);

  final LlmServiceErrorCode code;
  final String message;

  @override
  String toString() => 'LlmServiceException($code): $message';
}
