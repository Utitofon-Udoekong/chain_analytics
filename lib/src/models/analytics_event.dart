import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

enum EventType { track, screen, identify }

class AnalyticsEvent {
  final String id;
  final EventType type;
  final String name;
  final Map<String, dynamic>? properties;
  final DateTime timestamp;
  final String sessionId;
  final String? userId;

  AnalyticsEvent({
    required this.id,
    required this.type,
    required this.name,
    this.properties,
    required this.timestamp,
    required this.sessionId,
    this.userId,
  });

  /// Create a track event
  factory AnalyticsEvent.track({
    required String id,
    required String name,
    Map<String, dynamic>? properties,
    required String sessionId,
    String? userId,
  }) {
    return AnalyticsEvent(
      id: id,
      type: EventType.track,
      name: name,
      properties: properties,
      timestamp: DateTime.now(),
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Create a screen event
  factory AnalyticsEvent.screen({
    required String id,
    required String name,
    Map<String, dynamic>? properties,
    required String sessionId,
    String? userId,
  }) {
    return AnalyticsEvent(
      id: id,
      type: EventType.screen,
      name: name,
      properties: properties,
      timestamp: DateTime.now(),
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Create an identify event
  factory AnalyticsEvent.identify({
    required String id,
    required String userId,
    Map<String, dynamic>? properties,
    required String sessionId,
  }) {
    return AnalyticsEvent(
      id: id,
      type: EventType.identify,
      name: 'identify',
      properties: properties,
      timestamp: DateTime.now(),
      sessionId: sessionId,
      userId: userId,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'properties': properties,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'userId': userId,
    };
  }

  /// Create from JSON
  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'] as String,
      type: EventType.values.firstWhere((e) => e.name == json['type']),
      name: json['name'] as String,
      properties: json['properties'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String?,
    );
  }

  /// Convert to database map
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'properties': properties != null ? jsonEncode(properties) : null,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'sessionId': sessionId,
      'userId': userId,
    };
  }

  /// Create from database map
  factory AnalyticsEvent.fromDbMap(Map<String, dynamic> map) {
    return AnalyticsEvent(
      id: map['id'] as String,
      type: EventType.values.firstWhere((e) => e.name == map['type']),
      name: map['name'] as String,
      properties: map['properties'] != null
          ? jsonDecode(map['properties'] as String) as Map<String, dynamic>
          : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      sessionId: map['sessionId'] as String,
      userId: map['userId'] as String?,
    );
  }

  @override
  String toString() {
    return 'AnalyticsEvent(type: ${type.name}, name: $name, timestamp: $timestamp)';
  }
}

/// Batch of events to be sent together
class EventBatch {
  final String batchId;
  final List<AnalyticsEvent> events;
  final DateTime createdAt;

  EventBatch({required this.batchId, required this.events, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  /// Convert batch to JSON
  Map<String, dynamic> toJson() {
    return {
      'batchId': batchId,
      'events': events.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Compress batch to bytes (for on-chain storage)
  Uint8List toCompressedBytes() {
    final jsonString = jsonEncode(toJson());
    final stringBytes = utf8.encode(jsonString);

    // Gzip compress
    final encoder = GZipEncoder();
    final compressed = encoder.encode(stringBytes);

    return Uint8List.fromList(compressed);
  }

  /// Create batch from compressed bytes
  static EventBatch fromCompressedBytes(Uint8List bytes) {
    final decoder = GZipDecoder();
    final decompressed = decoder.decodeBytes(bytes);
    final jsonString = utf8.decode(decompressed);
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    return EventBatch(
      batchId: json['batchId'] as String,
      events: (json['events'] as List)
          .map((e) => AnalyticsEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Get batch size in bytes (before compression)
  int get sizeBytes {
    return utf8.encode(jsonEncode(toJson())).length;
  }

  @override
  String toString() {
    return 'EventBatch(id: $batchId, events: ${events.length}, size: ${sizeBytes} bytes)';
  }
}
