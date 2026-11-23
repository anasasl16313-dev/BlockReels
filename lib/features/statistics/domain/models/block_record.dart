import '../../../../core/models/history_log.dart';
import '../../../../core/models/intervention_mode.dart';

/// Domain entity representing an individual intercepted short-form video blocking event.
class BlockRecord {
  final String id;
  final String packageName;
  final String appType; // 'INSTAGRAM', 'YOUTUBE', 'FACEBOOK', 'TIKTOK'
  final DateTime timestamp;
  final String interventionMode;
  final int estimatedTimeSavedSeconds;
  final bool wasOverridden;

  const BlockRecord({
    required this.id,
    required this.packageName,
    required this.appType,
    required this.timestamp,
    this.interventionMode = 'MINDFUL_PAUSE',
    this.estimatedTimeSavedSeconds = 45,
    this.wasOverridden = false,
  });

  BlockRecord copyWith({
    String? id,
    String? packageName,
    String? appType,
    DateTime? timestamp,
    String? interventionMode,
    int? estimatedTimeSavedSeconds,
    bool? wasOverridden,
  }) {
    return BlockRecord(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      appType: appType ?? this.appType,
      timestamp: timestamp ?? this.timestamp,
      interventionMode: interventionMode ?? this.interventionMode,
      estimatedTimeSavedSeconds:
          estimatedTimeSavedSeconds ?? this.estimatedTimeSavedSeconds,
      wasOverridden: wasOverridden ?? this.wasOverridden,
    );
  }

  factory BlockRecord.fromHistoryLog(HistoryLog log) => BlockRecord(
        id: log.id,
        packageName: log.packageName,
        appType: log.appName.toUpperCase(),
        timestamp: log.timestamp,
        interventionMode: log.interventionMode.name,
        estimatedTimeSavedSeconds: log.estimatedTimeSavedSeconds,
        wasOverridden: log.wasOverridden,
      );

  HistoryLog toHistoryLog() => HistoryLog(
        id: id,
        timestamp: timestamp,
        packageName: packageName,
        appName: appType,
        interventionMode: InterventionMode.fromString(interventionMode),
        estimatedTimeSavedSeconds: estimatedTimeSavedSeconds,
        wasOverridden: wasOverridden,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'packageName': packageName,
        'appType': appType,
        'timestamp': timestamp.toIso8601String(),
        'interventionMode': interventionMode,
        'estimatedTimeSavedSeconds': estimatedTimeSavedSeconds,
        'wasOverridden': wasOverridden,
      };

  factory BlockRecord.fromJson(Map<String, dynamic> json) => BlockRecord(
        id: json['id'] as String? ?? '',
        packageName: json['packageName'] as String? ?? '',
        appType: json['appType'] as String? ?? '',
        timestamp: json['timestamp'] is String
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : (json['timestamp'] is int
                ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
                : DateTime.now()),
        interventionMode:
            json['interventionMode'] as String? ?? 'MINDFUL_PAUSE',
        estimatedTimeSavedSeconds:
            json['estimatedTimeSavedSeconds'] as int? ?? 45,
        wasOverridden: json['wasOverridden'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          packageName == other.packageName &&
          appType == other.appType &&
          timestamp == other.timestamp &&
          interventionMode == other.interventionMode &&
          estimatedTimeSavedSeconds == other.estimatedTimeSavedSeconds &&
          wasOverridden == other.wasOverridden;

  @override
  int get hashCode =>
      id.hashCode ^
      packageName.hashCode ^
      appType.hashCode ^
      timestamp.hashCode ^
      interventionMode.hashCode ^
      estimatedTimeSavedSeconds.hashCode ^
      wasOverridden.hashCode;

  @override
  String toString() =>
      'BlockRecord(id: $id, app: $appType, time: $timestamp, saved: ${estimatedTimeSavedSeconds}s, overridden: $wasOverridden)';
}
