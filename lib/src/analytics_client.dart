import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'chain_analytics_config.dart';
import 'models/analytics_event.dart';
import 'storage/event_queue.dart';
import 'batching/event_batcher.dart';
import 'blockchain/chain_writer.dart';
import 'exceptions/chain_analytics_exception.dart';
import 'utils/logger.dart';

class AnalyticsClient {
  final ChainAnalyticsConfig config;
  final _uuid = const Uuid();

  late final EventQueue _eventQueue;
  late final EventBatcher _eventBatcher;
  late final ChainWriter _chainWriter;
  late final AnalyticsLogger _logger;

  String? _userId;
  Map<String, dynamic>? _userProperties;
  late String _sessionId;
  bool _isOptedOut = false;
  bool _isInitialized = false;

  AnalyticsClient(this.config);

  /// Initialize the client
  Future<void> initialize() async {
    if (_isInitialized) {
      throw ChainAnalyticsException('AnalyticsClient already initialized');
    }

    try {
      // Initialize logger first (needed for error logging)
      _logger = AnalyticsLogger(debug: config.debug);

      // Validate config
      config.validate();

      _logger.info('Initializing ChainAnalytics for app: ${config.appId}');

      // Generate session ID
      _sessionId = _uuid.v4();
      _logger.debug('Session ID: $_sessionId');

      // Initialize storage
      if (config.enableOfflineQueue) {
        _eventQueue = EventQueue(
          appId: config.appId,
          batchConfig: config.batchConfig,
          logger: _logger,
        );
        await _eventQueue.initialize();
        _logger.debug('Event queue initialized');
      }

      // Initialize chain writer
      _chainWriter = ChainWriter(config: config, logger: _logger);
      await _chainWriter.initialize();
      _logger.debug('Chain writer initialized');

      // Initialize batcher
      _eventBatcher = EventBatcher(
        config: config.batchConfig,
        onBatchReady: _sendBatch,
        logger: _logger,
      );
      _eventBatcher.start();
      _logger.debug('Event batcher started');

      // Process any queued events from previous session
      if (config.enableOfflineQueue) {
        await _processQueuedEvents();
      }

      _isInitialized = true;
      _logger.info('ChainAnalytics initialized successfully');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize ChainAnalytics', e, stackTrace);
      rethrow;
    }
  }

  /// Track a custom event
  Future<void> track(
    String eventName, [
    Map<String, dynamic>? properties,
  ]) async {
    if (_isOptedOut) {
      _logger.debug('User opted out, skipping event: $eventName');
      return;
    }

    if (!_isInitialized) {
      throw ChainAnalyticsException('AnalyticsClient not initialized');
    }

    try {
      final event = AnalyticsEvent.track(
        id: _uuid.v4(),
        name: eventName,
        properties: _mergeProperties(properties),
        sessionId: _sessionId,
        userId: _getHashedUserId(),
      );

      await _addEvent(event);
      _logger.debug('Tracked event: $eventName');
    } catch (e, stackTrace) {
      _logger.error('Failed to track event: $eventName', e, stackTrace);
    }
  }

  /// Track a screen view
  Future<void> screen(
    String screenName, [
    Map<String, dynamic>? properties,
  ]) async {
    if (_isOptedOut) {
      _logger.debug('User opted out, skipping screen: $screenName');
      return;
    }

    if (!_isInitialized) {
      throw ChainAnalyticsException('AnalyticsClient not initialized');
    }

    try {
      final event = AnalyticsEvent.screen(
        id: _uuid.v4(),
        name: screenName,
        properties: _mergeProperties(properties),
        sessionId: _sessionId,
        userId: _getHashedUserId(),
      );

      await _addEvent(event);
      _logger.debug('Tracked screen: $screenName');
    } catch (e, stackTrace) {
      _logger.error('Failed to track screen: $screenName', e, stackTrace);
    }
  }

  /// Set user ID
  void setUserId(String userId) {
    _userId = userId;
    _logger.debug('User ID set');

    // Track identify event
    track('identify', {'userId': _getHashedUserId()});
  }

  /// Set user properties
  void setUserProperties(Map<String, dynamic> properties) {
    _userProperties = {...?_userProperties, ...properties};
    _logger.debug('User properties updated: ${properties.keys}');
  }

  /// Flush all pending events immediately
  Future<void> flush() async {
    if (!_isInitialized) return;

    _logger.info('Flushing events...');
    await _eventBatcher.flush();
  }

  /// Reset session and user data
  Future<void> reset() async {
    if (!_isInitialized) return;

    _logger.info('Resetting session...');
    _userId = null;
    _userProperties = null;
    _sessionId = _uuid.v4();

    await flush();
  }

  /// Opt out of tracking
  Future<void> optOut() async {
    _isOptedOut = true;
    _logger.info('User opted out of tracking');

    // Clear queued events
    if (config.enableOfflineQueue) {
      await _eventQueue.clear();
    }
  }

  /// Opt back in
  Future<void> optIn() async {
    _isOptedOut = false;
    _logger.info('User opted in to tracking');
  }

  /// Add event to queue and batcher
  Future<void> _addEvent(AnalyticsEvent event) async {
    // Add to local queue first (if enabled)
    if (config.enableOfflineQueue) {
      await _eventQueue.enqueue(event);
    }

    // Add to batcher for processing
    _eventBatcher.addEvent(event);
  }

  /// Send a batch of events to chain
  Future<void> _sendBatch(EventBatch batch) async {
    try {
      _logger.info(
        'Sending batch ${batch.batchId} with ${batch.events.length} events',
      );

      final txHash = await _chainWriter.sendBatch(batch);

      _logger.info('Batch sent successfully. TX: $txHash');
      _logger.debug('Explorer: ${config.chain.getTransactionUrl(txHash)}');

      // Remove events from queue after successful send
      if (config.enableOfflineQueue) {
        for (final event in batch.events) {
          await _eventQueue.remove(event.id);
        }
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to send batch ${batch.batchId}', e, stackTrace);
      // Events remain in queue for retry
    }
  }

  /// Process any events from previous sessions
  Future<void> _processQueuedEvents() async {
    final queuedEvents = await _eventQueue.getAll();

    if (queuedEvents.isEmpty) {
      _logger.debug('No queued events to process');
      return;
    }

    _logger.info(
      'Processing ${queuedEvents.length} queued events from previous session',
    );

    for (final event in queuedEvents) {
      _eventBatcher.addEvent(event);
    }
  }

  /// Get hashed user ID (if privacy enabled)
  String? _getHashedUserId() {
    if (_userId == null) return null;

    if (config.hashUserIds) {
      final bytes = utf8.encode(_userId!);
      final hash = sha256.convert(bytes);
      return hash.toString();
    }

    return _userId;
  }

  /// Merge user properties with event properties
  Map<String, dynamic>? _mergeProperties(
    Map<String, dynamic>? eventProperties,
  ) {
    if (_userProperties == null && eventProperties == null) {
      return null;
    }

    return {...?_userProperties, ...?eventProperties};
  }

  /// Dispose resources
  Future<void> dispose() async {
    if (!_isInitialized) {
      return; // Already disposed or never initialized
    }

    _logger.info('Disposing ChainAnalytics...');

    await flush();
    _eventBatcher.stop();

    if (config.enableOfflineQueue) {
      await _eventQueue.close();
    }

    _isInitialized = false;
  }
}
