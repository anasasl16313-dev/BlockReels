/// Defensive scalar extraction for hostile or type-confused native payloads.
int peSafeInt(dynamic value, int fallback) => value is int ? value : fallback;

String peSafeString(dynamic value, String fallback) =>
    value is String ? value : fallback;

bool peSafeBool(dynamic value, bool fallback) =>
    value is bool ? value : fallback;

/// Abstract base class for all asynchronous events received from the Android platform layer.
abstract class PlatformEvent {
  final String eventType;
  final int timestamp;

  const PlatformEvent({
    required this.eventType,
    required this.timestamp,
  });

  factory PlatformEvent.fromJson(Map<String, dynamic> json) {
    final type = peSafeString(
      json['eventType'] ?? json['type'],
      '',
    );
    switch (type) {
      case 'REEL_BLOCKED':
        return BlockEvent.fromJson(json);
      case 'SERVICE_STATE_CHANGED':
        return ServiceStatusEvent.fromJson(json);
      case 'BATTERY_OPT_CHANGED':
        return BatteryOptEvent.fromJson(json);
      default:
        return GenericPlatformEvent(
          eventType: type,
          timestamp: peSafeInt(
            json['timestamp'],
            DateTime.now().millisecondsSinceEpoch,
          ),
          payload: json,
        );
    }
  }

  Map<String, dynamic> toJson();
}

/// Event emitted when a short-form video feed (Reel, Short, TikTok) is intercepted.
class BlockEvent extends PlatformEvent {
  final String? eventId;
  final bool durablyQueued;
  final String packageName;
  final String appType;
  final String interventionMode;
  final String detectionReason;

  const BlockEvent({
    this.eventId,
    this.durablyQueued = false,
    required super.timestamp,
    required this.packageName,
    required this.appType,
    required this.interventionMode,
    this.detectionReason = '',
  }) : super(eventType: 'REEL_BLOCKED');

  factory BlockEvent.fromJson(Map<String, dynamic> json) => BlockEvent(
        durablyQueued: json['durablyQueued'] == true,
        eventId: peSafeString(json['eventId'], '').trim().isEmpty
            ? null
            : json['eventId'] as String,
        timestamp: peSafeInt(
          json['timestamp'],
          DateTime.now().millisecondsSinceEpoch,
        ),
        packageName: peSafeString(
          json['packageName'] ?? json['app'],
          '',
        ),
        appType: peSafeString(
          json['appType'] ?? json['appName'] ?? json['app'],
          '',
        ),
        interventionMode: peSafeString(
          json['interventionMode'] ?? json['action'],
          'MINDFUL_PAUSE',
        ),
        detectionReason:
            peSafeString(json['detectionReason'], 'SURGICAL_HEURISTIC'),
      );

  @override
  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        if (durablyQueued) 'durablyQueued': true,
        if (eventId != null) 'eventId': eventId,
        'timestamp': timestamp,
        'packageName': packageName,
        'appType': appType,
        'interventionMode': interventionMode,
        'detectionReason': detectionReason,
      };

  @override
  String toString() =>
      'BlockEvent(app: $appType, mode: $interventionMode, time: $timestamp)';
}

/// Event emitted when the native Accessibility Service is enabled, disabled, or interrupted.
class ServiceStatusEvent extends PlatformEvent {
  final bool isEnabled;

  const ServiceStatusEvent({
    required super.timestamp,
    required this.isEnabled,
  }) : super(eventType: 'SERVICE_STATE_CHANGED');

  factory ServiceStatusEvent.fromJson(Map<String, dynamic> json) =>
      ServiceStatusEvent(
        timestamp: peSafeInt(
          json['timestamp'],
          DateTime.now().millisecondsSinceEpoch,
        ),
        isEnabled: peSafeBool(json['isEnabled'] ?? json['enabled'], false),
      );

  @override
  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'timestamp': timestamp,
        'isEnabled': isEnabled,
      };

  @override
  String toString() =>
      'ServiceStatusEvent(isEnabled: $isEnabled, time: $timestamp)';
}

/// Event emitted when battery optimization whitelist status changes.
class BatteryOptEvent extends PlatformEvent {
  final bool isIgnored;

  const BatteryOptEvent({
    required super.timestamp,
    required this.isIgnored,
  }) : super(eventType: 'BATTERY_OPT_CHANGED');

  factory BatteryOptEvent.fromJson(Map<String, dynamic> json) =>
      BatteryOptEvent(
        timestamp: peSafeInt(
          json['timestamp'],
          DateTime.now().millisecondsSinceEpoch,
        ),
        isIgnored: peSafeBool(json['isIgnored'], false),
      );

  @override
  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'timestamp': timestamp,
        'isIgnored': isIgnored,
      };
}

/// Generic container for unexpected or forward-compatible platform events.
class GenericPlatformEvent extends PlatformEvent {
  final Map<String, dynamic> payload;

  const GenericPlatformEvent({
    required super.eventType,
    required super.timestamp,
    required this.payload,
  });

  @override
  Map<String, dynamic> toJson() => {
        'eventType': eventType,
        'timestamp': timestamp,
        ...payload,
      };
}
