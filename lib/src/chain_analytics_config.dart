import 'models/supported_chain.dart';
import 'models/batch_config.dart';

class ChainAnalyticsConfig {
  /// Unique identifier for your app
  final String appId;

  /// The blockchain network to use
  final SupportedChain chain;

  /// RPC URL for the blockchain network
  final String rpcUrl;

  /// Private key for the burner wallet that will send transactions
  /// IMPORTANT: Generate a unique key per app, fund it with minimal gas
  final String privateKey;

  /// Contract address for the EventLogger (optional - uses calldata if null)
  final String? contractAddress;

  /// Batching configuration
  final BatchConfig batchConfig;

  /// Enable debug logging
  final bool debug;

  /// Hash user IDs for privacy (recommended: true)
  final bool hashUserIds;

  /// Automatically track screen views via NavigatorObserver
  final bool autoTrackScreens;

  /// Enable offline queueing (stores events locally when no internet)
  final bool enableOfflineQueue;

  const ChainAnalyticsConfig({
    required this.appId,
    required this.chain,
    required this.privateKey,
    required this.rpcUrl,
    this.contractAddress,
    this.batchConfig = const BatchConfig(),
    this.debug = false,
    this.hashUserIds = true,
    this.autoTrackScreens = true,
    this.enableOfflineQueue = true,
  });

  /// Validate configuration
  void validate() {
    if (appId.isEmpty) {
      throw ArgumentError('appId cannot be empty');
    }

    if (privateKey.isEmpty) {
      throw ArgumentError('privateKey cannot be empty');
    }

    // Basic private key format check (should start with 0x and be 66 chars)
    if (!privateKey.startsWith('0x') || privateKey.length != 66) {
      throw ArgumentError(
        'privateKey must be a valid Ethereum private key (0x + 64 hex chars)',
      );
    }

    if (rpcUrl.isEmpty) {
      throw ArgumentError('rpcUrl cannot be empty');
    }

    // Basic URL format validation
    try {
      final uri = Uri.parse(rpcUrl);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw ArgumentError('rpcUrl must be a valid HTTP or HTTPS URL');
      }
    } catch (e) {
      throw ArgumentError('rpcUrl must be a valid URL: $e');
    }

    batchConfig.validate();
  }

  /// Get the RPC URL
  String getRpcUrl() {
    return rpcUrl;
  }

  /// Create a copy with updated values
  ChainAnalyticsConfig copyWith({
    String? appId,
    SupportedChain? chain,
    String? rpcUrl,
    String? privateKey,
    String? contractAddress,
    BatchConfig? batchConfig,
    bool? debug,
    bool? hashUserIds,
    bool? autoTrackScreens,
    bool? enableOfflineQueue,
  }) {
    return ChainAnalyticsConfig(
      appId: appId ?? this.appId,
      chain: chain ?? this.chain,
      rpcUrl: rpcUrl ?? this.rpcUrl,
      privateKey: privateKey ?? this.privateKey,
      contractAddress: contractAddress ?? this.contractAddress,
      batchConfig: batchConfig ?? this.batchConfig,
      debug: debug ?? this.debug,
      hashUserIds: hashUserIds ?? this.hashUserIds,
      autoTrackScreens: autoTrackScreens ?? this.autoTrackScreens,
      enableOfflineQueue: enableOfflineQueue ?? this.enableOfflineQueue,
    );
  }
}
