class BatchConfig {
  /// Maximum number of events in a batch before sending
  final int maxBatchSize;
  
  /// Maximum time to wait before sending a batch (even if not full)
  final Duration maxBatchInterval;
  
  /// Maximum number of retries for failed transactions
  final int maxRetries;
  
  /// Initial retry delay (doubles with each retry)
  final Duration retryDelay;
  
  /// Maximum size of the local queue (prevents unbounded growth)
  final int maxQueueSize;
  
  const BatchConfig({
    this.maxBatchSize = 50,
    this.maxBatchInterval = const Duration(minutes: 5),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.maxQueueSize = 1000,
  });
  
  void validate() {
    if (maxBatchSize <= 0) {
      throw ArgumentError('maxBatchSize must be positive');
    }
    
    if (maxBatchInterval.inMilliseconds <= 0) {
      throw ArgumentError('maxBatchInterval must be positive');
    }
    
    if (maxRetries < 0) {
      throw ArgumentError('maxRetries cannot be negative');
    }
    
    if (maxQueueSize <= 0) {
      throw ArgumentError('maxQueueSize must be positive');
    }
  }
  
  BatchConfig copyWith({
    int? maxBatchSize,
    Duration? maxBatchInterval,
    int? maxRetries,
    Duration? retryDelay,
    int? maxQueueSize,
  }) {
    return BatchConfig(
      maxBatchSize: maxBatchSize ?? this.maxBatchSize,
      maxBatchInterval: maxBatchInterval ?? this.maxBatchInterval,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      maxQueueSize: maxQueueSize ?? this.maxQueueSize,
    );
  }
}