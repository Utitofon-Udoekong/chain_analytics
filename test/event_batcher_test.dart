import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

import 'package:chain_analytics/chain_analytics.dart';

void main() {
  group('EventBatcher', () {
    late AnalyticsLogger logger;
    late BatchConfig config;
    late List<EventBatch> capturedBatches;
    late Future<void> Function(EventBatch) onBatchReady;

    setUp(() {
      logger = AnalyticsLogger(debug: false);
      capturedBatches = [];
      onBatchReady = (batch) {
        capturedBatches.add(batch);
        return Future.value();
      };
    });

    group('size-based batching', () {
      test('sends batch when max size reached', () {
        config = const BatchConfig(maxBatchSize: 3);
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        // Add events up to max size
        batcher.addEvent(_createEvent('event1'));
        batcher.addEvent(_createEvent('event2'));
        expect(capturedBatches.length, 0);

        batcher.addEvent(_createEvent('event3'));
        expect(capturedBatches.length, 1);
        expect(capturedBatches[0].events.length, 3);
      });

      test('creates multiple batches when exceeding max size', () {
        config = const BatchConfig(maxBatchSize: 2);
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        batcher.addEvent(_createEvent('event1'));
        batcher.addEvent(_createEvent('event2'));
        expect(capturedBatches.length, 1);

        batcher.addEvent(_createEvent('event3'));
        batcher.addEvent(_createEvent('event4'));
        expect(capturedBatches.length, 2);

        batcher.addEvent(_createEvent('event5'));
        expect(capturedBatches.length, 2); // Not yet at threshold
      });
    });

    group('time-based batching', () {
      test('sends batch after max interval', () {
        fakeAsync((async) {
          config = const BatchConfig(
            maxBatchSize: 100,
            maxBatchInterval: Duration(milliseconds: 100),
          );
          final batcher = EventBatcher(
            config: config,
            onBatchReady: onBatchReady,
            logger: logger,
          );

          batcher.start();
          batcher.addEvent(_createEvent('event1'));

          // Should not have sent yet
          expect(capturedBatches.length, 0);

          // Wait for interval
          async.elapse(Duration(milliseconds: 150));
          expect(capturedBatches.length, 1);
          expect(capturedBatches[0].events.length, 1);
        });
      });

      test('handles multiple time-based batches', () {
        fakeAsync((async) {
          config = const BatchConfig(
            maxBatchSize: 100,
            maxBatchInterval: Duration(milliseconds: 50),
          );
          final batcher = EventBatcher(
            config: config,
            onBatchReady: onBatchReady,
            logger: logger,
          );

          batcher.start();
          batcher.addEvent(_createEvent('event1'));
          async.elapse(Duration(milliseconds: 60));
          expect(capturedBatches.length, 1);

          batcher.addEvent(_createEvent('event2'));
          async.elapse(Duration(milliseconds: 60));
          expect(capturedBatches.length, 2);
        });
      });
    });

    group('flush', () {
      test('sends all pending events immediately', () async {
        config = const BatchConfig(
          maxBatchSize: 10,
          maxBatchInterval: Duration(hours: 1),
        );
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        batcher.addEvent(_createEvent('event1'));
        batcher.addEvent(_createEvent('event2'));
        expect(capturedBatches.length, 0);

        await batcher.flush();
        expect(capturedBatches.length, 1);
        expect(capturedBatches[0].events.length, 2);
      });

      test('does not send if no pending events', () async {
        config = const BatchConfig();
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        await batcher.flush();
        expect(capturedBatches.length, 0);
      });
    });

    group('lifecycle', () {
      test('start starts timer', () {
        config = const BatchConfig(maxBatchInterval: Duration(seconds: 1));
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        expect(batcher.isRunning, false);
        batcher.start();
        expect(batcher.isRunning, true);
      });

      test('stop stops timer and prevents new batches', () {
        config = const BatchConfig(maxBatchInterval: Duration(seconds: 1));
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        batcher.start();
        batcher.addEvent(_createEvent('event1'));
        expect(capturedBatches.length, 0);

        batcher.stop();
        expect(batcher.isRunning, false);

        // Timer should not trigger after stop
        fakeAsync((async) {
          async.elapse(Duration(seconds: 2));
          expect(capturedBatches.length, 0);
        });
      });

      test('duplicate start does not create multiple timers', () {
        config = const BatchConfig(maxBatchInterval: Duration(seconds: 1));
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        batcher.start();
        expect(batcher.isRunning, true);

        batcher.start(); // Should be idempotent
        expect(batcher.isRunning, true);

        batcher.stop();
        expect(batcher.isRunning, false);
      });
    });

    group('batch metadata', () {
      test('generates unique batch IDs', () {
        config = const BatchConfig(maxBatchSize: 1);
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        batcher.addEvent(_createEvent('event1'));
        batcher.addEvent(_createEvent('event2'));

        expect(capturedBatches.length, 2);
        expect(capturedBatches[0].batchId, isNotEmpty);
        expect(capturedBatches[1].batchId, isNotEmpty);
        expect(capturedBatches[0].batchId, isNot(capturedBatches[1].batchId));
      });

      test('includes createdAt timestamp', () {
        config = const BatchConfig(maxBatchSize: 1);
        final batcher = EventBatcher(
          config: config,
          onBatchReady: onBatchReady,
          logger: logger,
        );

        batcher.addEvent(_createEvent('event1'));

        expect(capturedBatches.length, 1);
        expect(capturedBatches[0].createdAt, isA<DateTime>());
        expect(
          capturedBatches[0].createdAt.isBefore(
            DateTime.now().add(Duration(seconds: 1)),
          ),
          isTrue,
        );
      });
    });
  });
}

AnalyticsEvent _createEvent(String name) {
  return AnalyticsEvent.track(
    id: 'test-$name',
    name: name,
    sessionId: 'test-session',
  );
}
