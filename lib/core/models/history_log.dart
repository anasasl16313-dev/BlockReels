import 'intervention_mode.dart';

/// Represents a persistent historical record of an intercepted short-form video feed.
class HistoryLog {
  final String id;
  final DateTime timestamp;
  final String packageName;
  final String appName;
  final InterventionMode interventionMode;
  final int estimatedTimeSavedSeconds;
  final bool wasDismissedWithHold;
  final String detectionReason;
  final bool wasOverridden;

  HistoryLog({
    required this.id,
    required this.timestamp,
    required this.packageName,
    required this.appName,
    required this.interventionMode,
    this.estimatedTimeSavedSeconds = 45,
    this.wasDismissedWithHold = false,
    this.detectionReason = 'SURGICAL_HEURISTIC',
    this.wasOverridden = false,
  });

  HistoryLog copyWith({
    String? id,
    DateTime? timestamp,
    String? packageName,
    String? appName,
    InterventionMode? interventionMode,
    int? estimatedTimeSavedSeconds,
    bool? wasDismissedWithHold,
    String? detectionReason,
    bool? wasOverridden,
  }) {
    return HistoryLog(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      interventionMode: interventionMode ?? this.interventionMode,
      estimatedTimeSavedSeconds:
          estimatedTimeSavedSeconds ?? this.estimatedTimeSavedSeconds,
      wasDismissedWithHold: wasDismissedWithHold ?? this.wasDismissedWithHold,
      detectionReason: detectionReason ?? this.detectionReason,
      wasOverridden: wasOverridden ?? this.wasOverridden,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'packageName': packageName,
      'appName': appName,
      'interventionMode': interventionMode.name,
      'estimatedTimeSavedSeconds': estimatedTimeSavedSeconds,
      'wasDismissedWithHold': wasDismissedWithHold,
      'detectionReason': detectionReason,
      'wasOverridden': wasOverridden,
    };
  }

  factory HistoryLog.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    final rawTs = json['timestamp'];
    if (rawTs is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    return HistoryLog(
      id: json['id'] as String? ?? '',
      timestamp: parsedTime,
      packageName: json['packageName'] as String? ?? '',
      appName: json['appName'] as String? ?? (json['appType'] as String? ?? ''),
      interventionMode: InterventionMode.fromString(
        json['interventionMode'] as String?,
      ),
      estimatedTimeSavedSeconds:
          json['estimatedTimeSavedSeconds'] as int? ?? 45,
      wasDismissedWithHold: json['wasDismissedWithHold'] as bool? ?? false,
      detectionReason:
          json['detectionReason'] as String? ?? 'SURGICAL_HEURISTIC',
      wasOverridden: json['wasOverridden'] as bool? ??
          (json['wasDismissedWithHold'] as bool? ?? false),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryLog &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timestamp == other.timestamp &&
          packageName == other.packageName &&
          appName == other.appName &&
          interventionMode == other.interventionMode &&
          estimatedTimeSavedSeconds == other.estimatedTimeSavedSeconds &&
          wasDismissedWithHold == other.wasDismissedWithHold &&
          detectionReason == other.detectionReason &&
          wasOverridden == other.wasOverridden;

  @override
  int get hashCode =>
      id.hashCode ^
      timestamp.hashCode ^
      packageName.hashCode ^
      appName.hashCode ^
      interventionMode.hashCode ^
      estimatedTimeSavedSeconds.hashCode ^
      wasDismissedWithHold.hashCode ^
      detectionReason.hashCode ^
      wasOverridden.hashCode;

  @override
  String toString() =>
      'HistoryLog(id: $id, app: $appName, time: $timestamp, saved: ${estimatedTimeSavedSeconds}s)';
}
