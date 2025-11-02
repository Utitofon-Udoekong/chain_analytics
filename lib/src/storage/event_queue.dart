import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

import '../models/analytics_event.dart';
import '../models/batch_config.dart';
import '../exceptions/chain_analytics_exception.dart';
import '../utils/logger.dart';

/// EventQueue handles offline storage of analytics events using SQLite
class EventQueue {
  final String appId;
  final BatchConfig? batchConfig;
  final AnalyticsLogger? logger;
  
  Database? _database;
  bool _initialized = false;
  
  EventQueue({
    required this.appId,
    this.batchConfig,
    this.logger,
  });
  
  /// Initialize the database and create table
  Future<void> initialize() async {
    if (_initialized) {
      throw QueueException('EventQueue already initialized');
    }
    
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'chain_analytics_$appId.db');
      
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _createTable,
      );
      
      _initialized = true;
      logger?.debug('EventQueue database opened: $path');
    } catch (e, stackTrace) {
      logger?.error('Failed to initialize EventQueue', e, stackTrace);
      throw QueueException(
        'Failed to initialize EventQueue: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Create the events table
  Future<void> _createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        properties TEXT,
        timestamp INTEGER NOT NULL,
        sessionId TEXT NOT NULL,
        userId TEXT
      )
    ''');
    
    // Add indexes for faster queries
    await db.execute('CREATE INDEX idx_timestamp ON events(timestamp)');
    await db.execute('CREATE INDEX idx_sessionId ON events(sessionId)');
  }
  
  /// Add an event to the queue
  Future<void> enqueue(AnalyticsEvent event) async {
    _checkInitialized();
    
    try {
      // Check queue size limit
      if (batchConfig != null && batchConfig!.maxQueueSize > 0) {
        final count = Sqflite.firstIntValue(
          await _database!.rawQuery('SELECT COUNT(*) FROM events')
        ) ?? 0;
        
        if (count >= batchConfig!.maxQueueSize) {
          logger?.debug('Queue full ($count/${batchConfig!.maxQueueSize}), removing oldest event');
          
          // Remove oldest event
          await _database!.rawDelete(
            'DELETE FROM events WHERE id = (SELECT id FROM events ORDER BY timestamp LIMIT 1)'
          );
        }
      }
      
      // Insert event
      await _database!.insert(
        'events',
        _eventToDbMap(event),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      logger?.debug('Event enqueued: ${event.id}');
    } catch (e, stackTrace) {
      logger?.error('Failed to enqueue event', e, stackTrace);
      throw QueueException(
        'Failed to enqueue event: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Get all events from the queue, ordered by timestamp
  Future<List<AnalyticsEvent>> getAll() async {
    _checkInitialized();
    
    try {
      final maps = await _database!.query(
        'events',
        orderBy: 'timestamp ASC',
      );
      
      return maps.map((map) => _eventFromDbMap(map)).toList();
    } catch (e, stackTrace) {
      logger?.error('Failed to get events', e, stackTrace);
      throw QueueException(
        'Failed to get events: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Remove an event by ID
  Future<void> remove(String id) async {
    _checkInitialized();
    
    try {
      await _database!.delete(
        'events',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      logger?.debug('Event removed: $id');
    } catch (e, stackTrace) {
      logger?.error('Failed to remove event', e, stackTrace);
      throw QueueException(
        'Failed to remove event: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Clear all events from the queue
  Future<void> clear() async {
    _checkInitialized();
    
    try {
      await _database!.delete('events');
      logger?.debug('Event queue cleared');
    } catch (e, stackTrace) {
      logger?.error('Failed to clear queue', e, stackTrace);
      throw QueueException(
        'Failed to clear queue: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Close the database connection
  Future<void> close() async {
    if (!_initialized) return;
    
    try {
      await _database?.close();
      _initialized = false;
      logger?.debug('EventQueue database closed');
    } catch (e, stackTrace) {
      logger?.error('Failed to close EventQueue', e, stackTrace);
      throw QueueException(
        'Failed to close EventQueue: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Convert AnalyticsEvent to database map
  Map<String, dynamic> _eventToDbMap(AnalyticsEvent event) {
    return {
      'id': event.id,
      'type': event.type.toString().split('.').last, // Convert enum to string
      'name': event.name,
      'properties': event.properties != null 
        ? jsonEncode(event.properties) 
        : null,
      'timestamp': event.timestamp.millisecondsSinceEpoch,
      'sessionId': event.sessionId,
      'userId': event.userId,
    };
  }
  
  /// Convert database map to AnalyticsEvent
  AnalyticsEvent _eventFromDbMap(Map<String, dynamic> map) {
    return AnalyticsEvent(
      id: map['id'] as String,
      type: EventType.values.firstWhere((e) => e.toString().split('.').last == map['type']),
      name: map['name'] as String,
      properties: map['properties'] != null
        ? jsonDecode(map['properties'] as String) as Map<String, dynamic>
        : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      sessionId: map['sessionId'] as String,
      userId: map['userId'] as String?,
    );
  }
  
  void _checkInitialized() {
    if (!_initialized || _database == null) {
      throw QueueException('EventQueue not initialized. Call initialize() first.');
    }
  }
}
