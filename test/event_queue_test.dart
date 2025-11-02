import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:chain_analytics/chain_analytics.dart';

void main() {
  // Initialize FFI for tests
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('EventQueue', () {
    late EventQueue queue;
    late AnalyticsLogger logger;

    setUp(() {
      logger = AnalyticsLogger(debug: false);
    });

    tearDown(() async {
      await queue.close();
    });

    group('basic operations', () {
      test('can initialize queue', () async {
        queue = EventQueue(appId: 'test-app', logger: logger);
        await queue.initialize();
        // Should not throw
      });

      test('can enqueue and retrieve events', () async {
        queue = EventQueue(appId: 'test-app-1', logger: logger);
        await queue.initialize();

        final event = _createEvent('test-event');
        await queue.enqueue(event);

        final events = await queue.getAll();
        expect(events.length, 1);
        expect(events[0].id, event.id);
        expect(events[0].name, event.name);
      });

      test('can remove event by id', () async {
        queue = EventQueue(appId: 'test-app-2', logger: logger);
        await queue.initialize();

        final event1 = _createEvent('event1');
        final event2 = _createEvent('event2');
        await queue.enqueue(event1);
        await queue.enqueue(event2);

        expect((await queue.getAll()).length, 2);

        await queue.remove(event1.id);
        final remaining = await queue.getAll();
        expect(remaining.length, 1);
        expect(remaining[0].id, event2.id);
      });

      test('can clear all events', () async {
        queue = EventQueue(appId: 'test-app-3', logger: logger);
        await queue.initialize();

        for (int i = 0; i < 5; i++) {
          await queue.enqueue(_createEvent('event$i'));
        }

        expect((await queue.getAll()).length, 5);

        await queue.clear();
        expect((await queue.getAll()).length, 0);
      });

      test('returns events in chronological order', () async {
        queue = EventQueue(appId: 'test-app-4', logger: logger);
        await queue.initialize();

        // Add events with slight delays
        await queue.enqueue(_createEvent('event1'));
        await Future.delayed(Duration(milliseconds: 10));
        await queue.enqueue(_createEvent('event2'));
        await Future.delayed(Duration(milliseconds: 10));
        await queue.enqueue(_createEvent('event3'));

        final events = await queue.getAll();
        expect(events.length, 3);
        expect(events[0].name, 'event1');
        expect(events[1].name, 'event2');
        expect(events[2].name, 'event3');
      });
    });

    group('serialization', () {
      test('preserves event properties', () async {
        queue = EventQueue(appId: 'test-app-5', logger: logger);
        await queue.initialize();

        final event = AnalyticsEvent.track(
          id: 'test-id',
          name: 'test-event',
          properties: {'key1': 'value1', 'key2': 123},
          sessionId: 'session-123',
          userId: 'user-456',
        );

        await queue.enqueue(event);
        final retrieved = await queue.getAll();

        expect(retrieved.length, 1);
        expect(retrieved[0].properties, {'key1': 'value1', 'key2': 123});
        expect(retrieved[0].sessionId, 'session-123');
        expect(retrieved[0].userId, 'user-456');
      });

      test('handles events without properties', () async {
        queue = EventQueue(appId: 'test-app-6', logger: logger);
        await queue.initialize();

        final event = AnalyticsEvent.track(
          id: 'test-id',
          name: 'test-event',
          properties: null,
          sessionId: 'session-123',
          userId: null,
        );

        await queue.enqueue(event);
        final retrieved = await queue.getAll();

        expect(retrieved.length, 1);
        expect(retrieved[0].properties, isNull);
        expect(retrieved[0].userId, isNull);
      });

      test('handles complex properties', () async {
        queue = EventQueue(appId: 'test-app-7', logger: logger);
        await queue.initialize();

        final event = AnalyticsEvent.track(
          id: 'test-id',
          name: 'test-event',
          properties: {
            'string': 'text',
            'number': 123,
            'boolean': true,
            'array': [1, 2, 3],
            'nested': {'key': 'value'},
          },
          sessionId: 'session-123',
          userId: 'user-456',
        );

        await queue.enqueue(event);
        final retrieved = await queue.getAll();

        expect(retrieved.length, 1);
        expect(retrieved[0].properties, {
          'string': 'text',
          'number': 123,
          'boolean': true,
          'array': [1, 2, 3],
          'nested': {'key': 'value'},
        });
      });
    });

    group('max queue size', () {
      test('enforces max queue size', () async {
        final batchConfig = BatchConfig(maxQueueSize: 5);
        queue = EventQueue(
          appId: 'test-app-8',
          batchConfig: batchConfig,
          logger: logger,
        );
        await queue.initialize();

        // Add more events than max size
        for (int i = 0; i < 7; i++) {
          await queue.enqueue(_createEvent('event$i'));
        }

        // Should only keep maxQueueSize events, oldest removed
        final events = await queue.getAll();
        expect(events.length, 5);
        // First 2 should be removed (oldest)
        expect(events[0].name, 'event2');
        expect(events[1].name, 'event3');
      });

      test('does not enforce limit if maxQueueSize is 0', () async {
        final batchConfig = BatchConfig(maxQueueSize: 0);
        queue = EventQueue(
          appId: 'test-app-9',
          batchConfig: batchConfig,
          logger: logger,
        );
        await queue.initialize();

        for (int i = 0; i < 10; i++) {
          await queue.enqueue(_createEvent('event$i'));
        }

        final events = await queue.getAll();
        expect(events.length, 10);
      });

      test('does not enforce limit if no batchConfig', () async {
        queue = EventQueue(appId: 'test-app-10', logger: logger);
        await queue.initialize();

        for (int i = 0; i < 10; i++) {
          await queue.enqueue(_createEvent('event$i'));
        }

        final events = await queue.getAll();
        expect(events.length, 10);
      });
    });

    group('errors', () {
      test('throws on double initialization', () async {
        queue = EventQueue(appId: 'test-app-11', logger: logger);
        await queue.initialize();

        expect(() => queue.initialize(), throwsException);
      });

      test('throws on operation before initialization', () async {
        queue = EventQueue(appId: 'test-app-12', logger: logger);

        expect(() => queue.enqueue(_createEvent('event')), throwsException);
        expect(() => queue.getAll(), throwsException);
        expect(() => queue.remove('id'), throwsException);
      });

      test('handles close gracefully when not initialized', () async {
        queue = EventQueue(appId: 'test-app-13', logger: logger);
        // Should not throw
        await queue.close();
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
