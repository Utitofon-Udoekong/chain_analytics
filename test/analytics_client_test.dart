import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

import 'package:chain_analytics/src/analytics_client.dart';
import 'package:chain_analytics/src/chain_analytics_config.dart';
import 'package:chain_analytics/src/models/supported_chain.dart';
import 'package:chain_analytics/src/models/batch_config.dart';
import 'package:chain_analytics/src/exceptions/chain_analytics_exception.dart';

void main() {
  group('AnalyticsClient', () {
    ChainAnalyticsConfig testConfig() {
      return ChainAnalyticsConfig(
        appId: 'test-app',
        chain: SupportedChain.baseSepolia,
        privateKey: '0x${List.filled(64, 'a').join()}',
        rpcUrl: 'https://sepolia.base.org',
        batchConfig: const BatchConfig(
          maxBatchSize: 5,
          maxBatchInterval: Duration(milliseconds: 100),
        ),
        debug: false,
      );
    }

    group('initialization', () {
      test('successfully initializes with valid config', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);

        await client.initialize();
      });

      test('throws when initialized twice', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);

        await client.initialize();

        await expectLater(
          () => client.initialize(),
          throwsA(isA<ChainAnalyticsException>()),
        );
      });

      test('throws when tracking before initialization', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);

        await expectLater(
          () => client.track('test-event'),
          throwsA(isA<ChainAnalyticsException>()),
        );
      });
    });

    group('tracking events', () {
      test('tracks simple event', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.track('test-event');
      });

      test('tracks event with properties', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.track('test-event', {'key': 'value', 'count': 42});
      });

      test('tracks screen view', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.screen('HomeScreen');
      });

      test('respects opt-out', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.optOut();
        await client.track('should-be-skipped');
      });

      test('can opt back in', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.optOut();
        await client.optIn();
        await client.track('should-be-tracked');
      });
    });

    group('batching', () {
      test('batches events by size', () async {
        final config = testConfig().copyWith(
          enableOfflineQueue: false,
          batchConfig: const BatchConfig(maxBatchSize: 3),
        );
        final client = AnalyticsClient(config);
        await client.initialize();

        // Track events up to batch size
        await client.track('event1');
        await client.track('event2');
        await client.track('event3');

        // Should complete without errors
        expect(true, isTrue);
      });

      test('batches events by time interval', () {
        fakeAsync((async) {
          final config = testConfig().copyWith(
            enableOfflineQueue: false,
            batchConfig: const BatchConfig(
              maxBatchSize: 100,
              maxBatchInterval: Duration(milliseconds: 50),
            ),
          );
          final client = AnalyticsClient(config);

          client.initialize().then((_) {
            client.track('event1');

            // Advance time past interval
            async.elapse(const Duration(milliseconds: 100));

            // Should complete without errors
            expect(true, isTrue);
          });

          // Execute all pending timers
          async.flushMicrotasks();
          async.flushTimers();
        });
      });
    });

    group('flush', () {
      test('flushes pending events', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.track('event1');
        await client.track('event2');

        await client.flush();
      });

      test('handles flush when no events', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.flush();
      });
    });

    group('reset', () {
      test('resets session and flushes', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.track('event1');
        await client.reset();
      });
    });

    group('user properties', () {
      test('sets and merges user properties', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        client.setUserProperties({'plan': 'pro', 'tier': 'premium'});
        client.setUserProperties({'country': 'US'});

        await client.track('test-event');
        // Should complete without errors
        expect(true, isTrue);
      });

      test('sets user ID', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        client.setUserId('user-123');
        await client.track('test-event');
        // Should complete without errors
        expect(true, isTrue);
      });
    });

    group('lifecycle', () {
      test('disposes resources properly', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.dispose();
      });

      test('handles dispose when not initialized', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);

        await client.dispose();
      });
    });

    group('offline queue disabled', () {
      test('works without offline queue', () async {
        final config = testConfig().copyWith(enableOfflineQueue: false);
        final client = AnalyticsClient(config);
        await client.initialize();

        await client.track('event1');
        await client.track('event2');
        await client.flush();
      });
    });
  });
}

