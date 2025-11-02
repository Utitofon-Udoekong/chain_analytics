import 'dart:async';
import 'package:uuid/uuid.dart';

import '../models/batch_config.dart';
import '../models/analytics_event.dart';
import '../utils/logger.dart';

/// EventBatcher manages batching of events before sending to chain
class EventBatcher {
  final BatchConfig config;
  final Future<void> Function(EventBatch batch) onBatchReady;
  final AnalyticsLogger? logger;

  final List<AnalyticsEvent> _events = [];
  Timer? _timer;
  bool _isRunning = false;
  final _uuid = const Uuid();

  EventBatcher({required this.config, required this.onBatchReady, this.logger});

  /// Start the interval timer for periodic batching
  void start() {
    if (_isRunning) {
      logger?.debug('EventBatcher already running');
      return;
    }

    _isRunning = true;

    // Start periodic timer to check for batches
    _timer = Timer.periodic(config.maxBatchInterval, (_) {
      // Fire and forget - errors handled inside
      unawaited(_checkAndSend());
    });

    logger?.debug(
      'EventBatcher started with ${config.maxBatchInterval.inSeconds}s interval',
    );
  }

  /// Stop the timer and flush any pending events
  void stop() {
    if (!_isRunning) return;

    _isRunning = false;
    _timer?.cancel();
    _timer = null;

    logger?.debug('EventBatcher stopped');
  }

  /// Add an event to the current batch
  void addEvent(AnalyticsEvent event) {
    _events.add(event);
    logger?.debug(
      'Event added to batch (${_events.length}/${config.maxBatchSize})',
    );

    // Check if we've reached the batch size threshold
    if (_events.length >= config.maxBatchSize) {
      logger?.debug('Batch size limit reached, sending batch');
      _checkAndSend();
    }
  }

  /// Flush all pending events immediately
  Future<void> flush() async {
    if (_events.isEmpty) {
      logger?.debug('No events to flush');
      return;
    }

    logger?.debug('Flushing ${_events.length} events');
    await _checkAndSend();
  }

  /// Check if there are events to send and send them
  Future<void> _checkAndSend() async {
    if (_events.isEmpty) return;

    try {
      await _sendBatch();
    } catch (e, stackTrace) {
      logger?.error('Failed to send batch', e, stackTrace);
      // Don't rethrow - events stay in batch for retry
    }
  }

  /// Create and send a batch
  Future<void> _sendBatch() async {
    if (_events.isEmpty) return;

    // Create a copy of events and clear the buffer
    final eventsToSend = List<AnalyticsEvent>.from(_events);
    _events.clear();

    // Generate batch ID
    final batchId = _uuid.v4();

    // Create batch
    final batch = EventBatch(
      batchId: batchId,
      events: eventsToSend,
      createdAt: DateTime.now(),
    );

    logger?.debug('Sending batch $batchId with ${eventsToSend.length} events');

    // Call the callback (will log success/failure internally)
    await onBatchReady(batch);
  }

  /// Get the current batch size
  int get currentBatchSize => _events.length;

  /// Get whether the batcher is running
  bool get isRunning => _isRunning;
}
