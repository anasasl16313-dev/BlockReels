import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/installed_app_info.dart';
import '../models/rule_model.dart';
import 'dtos/intervention_config_dto.dart';
import 'dtos/platform_event.dart';
import 'dtos/realtime_metrics_dto.dart';
import 'dtos/schedule_dto.dart';
import 'platform_bridge.dart';

/// Production implementation of [PlatformBridge] using Flutter's [MethodChannel] and [EventChannel].
class MethodChannelPlatformBridge implements PlatformBridge {
  static const MethodChannel _platformChannel =
      MethodChannel('com.blockreels.app/platform');
  static const MethodChannel _legacyPlatformChannel =
      MethodChannel('com.blockreels/accessibility_control');

  static const EventChannel _eventChannel =
      EventChannel('com.blockreels.app/events');

  Stream<PlatformEvent>? _cachedEventStream;
  Stream<BlockEvent>? _cachedBlockEventsStream;
  Stream<bool>? _cachedServiceStatusStream;

  Future<T?> _invokeWithFallback<T>(String method, [dynamic arguments]) async {
    try {
      return await _platformChannel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      try {
        return await _legacyPlatformChannel.invokeMethod<T>(method, arguments);
      } catch (e) {
        debugPrint(
            '[MethodChannelPlatformBridge] Legacy fallback invoke failed for $method: $e');
        return null;
      }
    } on PlatformException catch (e) {
      debugPrint(
          '[MethodChannelPlatformBridge] PlatformException on $method: $e');
      return null;
    } catch (e) {
      debugPrint(
          '[MethodChannelPlatformBridge] Unexpected error on $method: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 1. Accessibility Service Permissions & Status
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isAccessibilityServiceEnabled() async {
    final res =
        await _invokeWithFallback<bool>('isAccessibilityServiceEnabled');
    return res ?? false;
  }

  @override
  Future<bool> requestAccessibilityPermission() async {
    final res = await _invokeWithFallback<bool>('openAccessibilitySettings') ??
        await _invokeWithFallback<bool>('requestAccessibilityPermission');
    return res ?? false;
  }

  // ---------------------------------------------------------------------------
  // 2. Battery Optimization
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isBatteryOptimizationDisabled() async {
    final res =
        await _invokeWithFallback<bool>('isBatteryOptimizationIgnored') ??
            await _invokeWithFallback<bool>('isBatteryOptimizationDisabled');
    return res ?? false;
  }

  @override
  Future<bool> requestDisableBatteryOptimization() async {
    final res = await _invokeWithFallback<bool>(
            'requestIgnoreBatteryOptimization') ??
        await _invokeWithFallback<bool>('requestDisableBatteryOptimization');
    return res ?? false;
  }

  // ---------------------------------------------------------------------------
  // 3. System Overlay Permission
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isOverlayPermissionGranted() async {
    final res = await _invokeWithFallback<bool>('isOverlayPermissionGranted');
    return res ?? false;
  }

  @override
  Future<bool> requestOverlayPermission() async {
    final res = await _invokeWithFallback<bool>('requestOverlayPermission');
    return res ?? false;
  }

  // ---------------------------------------------------------------------------
  // 4. Usage Statistics Permission
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isUsageStatsPermissionGranted() async {
    final res =
        await _invokeWithFallback<bool>('isUsageStatsPermissionGranted');
    return res ?? false;
  }

  @override
  Future<bool> requestUsageStatsPermission() async {
    final res = await _invokeWithFallback<bool>('requestUsageStatsPermission');
    return res ?? false;
  }

  // ---------------------------------------------------------------------------
  // 5. Rule, Toggle, Schedule & Settings Synchronization
  // ---------------------------------------------------------------------------

  @override
  Future<bool> syncRules(List<RuleModel> rules) async {
    final payload = rules.map((r) => r.toJson()).toList();
    final res =
        await _invokeWithFallback<bool>('syncRules', {'rules': payload});
    return res ?? false;
  }

  @override
  Future<bool> syncAppToggles(Map<String, bool> appToggles) async {
    final res = await _invokeWithFallback<bool>('syncAppToggles', appToggles);
    return res ?? false;
  }

  @override
  Future<bool> syncInterventionConfig(InterventionConfigDto config) async {
    final res = await _invokeWithFallback<bool>(
      'syncInterventionConfig',
      config.toJson(),
    );
    return res ?? false;
  }

  @override
  Future<bool> syncSchedules(List<ScheduleDto> schedules) async {
    final payload = schedules.map((s) => s.toJson()).toList();
    final res = await _invokeWithFallback<bool>(
      'syncSchedules',
      {'schedules': payload},
    );
    return res ?? false;
  }

  @override
  Future<bool> syncRestoredProtection({
    required List<RuleModel> rules,
    required List<ScheduleDto> schedules,
    required InterventionConfigDto config,
    required AppSettings settings,
  }) async =>
      await _invokeWithFallback<bool>('syncRestoredProtection', {
        'rules': rules.map((rule) => rule.toJson()).toList(),
        'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
        'config': config.toJson(),
        'isMasterEnabled': settings.isMasterEnabled,
      }) ?? false;

  @override
  Future<bool> updateSettings(AppSettings settings) async {
    final res = await _invokeWithFallback<bool>(
      'updateSettings',
      {'isMasterEnabled': settings.isMasterEnabled},
    );
    return res ?? false;
  }

  @override
  Future<bool> grantTemporaryAllowance(
    String packageName, {
    int durationSeconds = 300,
  }) async {
    final res = await _invokeWithFallback<bool>(
      'grantTemporaryAllowance',
      {
        'packageName': packageName,
        'durationSeconds': durationSeconds,
      },
    );
    return res ?? false;
  }

  // ---------------------------------------------------------------------------
  // 6. Application Discovery & Foreground Service
  // ---------------------------------------------------------------------------

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async {
    final dynamic res = await _invokeWithFallback<dynamic>('getInstalledApps');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((m) => InstalledAppInfo.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    return const [];
  }

  @override
  Future<bool> startForegroundService() async {
    final res = await _invokeWithFallback<bool>('startForegroundService');
    return res ?? false;
  }

  @override
  Future<bool> stopForegroundService() async {
    final res = await _invokeWithFallback<bool>('stopForegroundService');
    return res ?? false;
  }

  @override
  Future<bool> isForegroundServiceRunning() async {
    final res = await _invokeWithFallback<bool>('isForegroundServiceRunning');
    return res ?? false;
  }

  // ---------------------------------------------------------------------------
  // 7. Realtime Metrics
  // ---------------------------------------------------------------------------

  @override
  Future<RealtimeMetricsDto> getRealtimeMetrics() async {
    final dynamic res =
        await _invokeWithFallback<dynamic>('getRealtimeMetrics');
    if (res is Map) {
      return RealtimeMetricsDto.fromJson(Map<String, dynamic>.from(res));
    }
    return RealtimeMetricsDto.empty();
  }

  // ---------------------------------------------------------------------------
  // 8. Event Streams
  // ---------------------------------------------------------------------------

  @override
  Future<bool> clearPendingBlockEvents() async =>
      await _invokeWithFallback<bool>('clearPendingBlockEvents') ?? false;

  @override
  Future<List<BlockEvent>> readPendingBlockEvents({int limit = 100}) async {
    final dynamic result = await _invokeWithFallback<dynamic>(
        'readPendingBlockEvents', {'limit': limit.clamp(1, 100)});
    if (result is! List) return [];
    return result
        .whereType<Map>()
        .map((event) => BlockEvent.fromJson(Map<String, dynamic>.from(event)))
        .toList();
  }

  @override
  Future<bool> acknowledgeBlockEvents(List<String> ids) async =>
      await _invokeWithFallback<bool>('acknowledgeBlockEvents', {'ids': ids}) ??
      false;

  @override
  Stream<PlatformEvent> get eventStream {
    _cachedEventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<PlatformEvent>((dynamic event) {
      if (event is Map) {
        return PlatformEvent.fromJson(Map<String, dynamic>.from(event));
      }
      return GenericPlatformEvent(
        eventType: 'UNKNOWN',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        payload: {'raw': event},
      );
    }).handleError((error) {
      debugPrint('[MethodChannelPlatformBridge] EventStream error: $error');
    }).asBroadcastStream();

    return _cachedEventStream!;
  }

  @override
  Stream<BlockEvent> get blockEventsStream {
    _cachedBlockEventsStream ??= eventStream
        .where((e) => e is BlockEvent)
        .cast<BlockEvent>()
        .asBroadcastStream();
    return _cachedBlockEventsStream!;
  }

  @override
  Stream<bool> get serviceStatusStream {
    _cachedServiceStatusStream ??= eventStream
        .where((e) => e is ServiceStatusEvent)
        .cast<ServiceStatusEvent>()
        .map((e) => e.isEnabled)
        .asBroadcastStream();
    return _cachedServiceStatusStream!;
  }
}
