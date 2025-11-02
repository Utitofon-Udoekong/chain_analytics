class ChainAnalyticsException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;
  
  ChainAnalyticsException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });
  
  @override
  String toString() {
    if (originalError != null) {
      return 'ChainAnalyticsException: $message\nCaused by: $originalError';
    }
    return 'ChainAnalyticsException: $message';
  }
}

class ChainWriteException extends ChainAnalyticsException {
  final String? transactionHash;
  
  ChainWriteException(
    super.message, {
    this.transactionHash,
    super.originalError,
    super.stackTrace,
  });
  
  @override
  String toString() {
    final base = super.toString();
    if (transactionHash != null) {
      return '$base\nTransaction: $transactionHash';
    }
    return base;
  }
}

class QueueException extends ChainAnalyticsException {
  QueueException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class BatchException extends ChainAnalyticsException {
  BatchException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}