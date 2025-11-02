// Core
import 'src/analytics_client.dart';
import 'src/chain_analytics_config.dart';
import 'src/exceptions/chain_analytics_exception.dart';

export 'src/analytics_client.dart';
export 'src/chain_analytics_config.dart';

// Models
export 'src/models/analytics_event.dart';
export 'src/models/supported_chain.dart';
export 'src/models/batch_config.dart';

// Exceptions
export 'src/exceptions/chain_analytics_exception.dart';

// Internal (for testing)
export 'src/storage/event_queue.dart';
export 'src/batching/event_batcher.dart';
export 'src/blockchain/chain_writer.dart';
export 'src/utils/logger.dart';

/// Main static access point
class ChainAnalytics {
  static AnalyticsClient? _instance;
  
  /// Initialize the analytics client. Call this once in main()
  static Future<void> initialize(ChainAnalyticsConfig config) async {
    _instance = AnalyticsClient(config);
    await _instance!.initialize();
  }
  
  /// Track a custom event
  static Future<void> track(String eventName, [Map<String, dynamic>? properties]) async {
    _checkInitialized();
    await _instance!.track(eventName, properties);
  }
  
  /// Track a screen view
  static Future<void> screen(String screenName, [Map<String, dynamic>? properties]) async {
    _checkInitialized();
    await _instance!.screen(screenName, properties);
  }
  
  /// Set user ID (will be hashed before sending to chain)
  static void setUserId(String userId) {
    _checkInitialized();
    _instance!.setUserId(userId);
  }
  
  /// Set user properties
  static void setUserProperties(Map<String, dynamic> properties) {
    _checkInitialized();
    _instance!.setUserProperties(properties);
  }
  
  /// Flush all pending events to chain immediately
  static Future<void> flush() async {
    _checkInitialized();
    await _instance!.flush();
  }
  
  /// Reset session and clear user data
  static Future<void> reset() async {
    _checkInitialized();
    await _instance!.reset();
  }
  
  /// Opt out of tracking (stops all event collection)
  static Future<void> optOut() async {
    _checkInitialized();
    await _instance!.optOut();
  }
  
  /// Opt back in to tracking
  static Future<void> optIn() async {
    _checkInitialized();
    await _instance!.optIn();
  }
  
  static void _checkInitialized() {
    if (_instance == null) {
      throw ChainAnalyticsException(
        'ChainAnalytics not initialized. Call ChainAnalytics.initialize() first.'
      );
    }
  }
}