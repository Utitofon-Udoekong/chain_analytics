class AnalyticsLogger {
  final bool _enabled;
  
  AnalyticsLogger({required bool debug}) : _enabled = debug;
  
  /// Log a debug message
  void debug(String message) {
    if (!_enabled) return;
    _log('DEBUG', message);
  }
  
  /// Log an info message
  void info(String message) {
    if (!_enabled) return;
    _log('INFO', message);
  }
  
  /// Log an error with exception and stack trace
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    
    final buffer = StringBuffer();
    buffer.writeln('[ChainAnalytics] [ERROR] [${_getTimestamp()}] $message');
    
    if (error != null) {
      buffer.writeln('Error: $error');
    }
    
    if (stackTrace != null) {
      buffer.writeln('Stack trace:');
      buffer.writeln(stackTrace);
    }
    
    print(buffer.toString());
  }
  
  void _log(String level, String message) {
    print('[ChainAnalytics] [$level] [${_getTimestamp()}] $message');
  }
  
  String _getTimestamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
           '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}
