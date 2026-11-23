import 'dart:async';

import '../models/app_settings.dart';
import '../models/installed_app_info.dart';
import '../models/rule_model.dart';
import 'dtos/intervention_config_dto.dart';
import 'dtos/platform_event.dart';
import 'dtos/realtime_metrics_dto.dart';
import 'dtos/schedule_dto.dart';

/// Abstract contract defining bidirectional communication between Flutter and the native OS.
abstract class PlatformBridge {
  // ---------------------------------------------------------------------------
  // 1. Accessibility Service Permissions & Status
  // ---------------------------------------------------------------------------

  /// Checks if BlockReelsAccessibilityService is currently enabled in Android Settings.
  Future<bool> isAccessibilityServiceEnabled();

  /// Launches the Android Accessibility Settings screen for user activation.
  Future<bool> requestAccessibilityPermission();

  // ---------------------------------------------------------------------------
  // 2. Battery Optimization Exemption
  // ---------------------------------------------------------------------------

  /// Checks whether the app is whitelisted from OS battery optimizations.
  Future<bool> isBatteryOptimizationDisabled();

  /// Dispatches the system prompt to request battery optimization exemption.
  Future<bool> requestDisableBatteryOptimization();

  // ---------------------------------------------------------------------------
  // 3. System Overlay Permission (Draw Over Other Apps)
  // ---------------------------------------------------------------------------

  /// Checks if SYSTEM_ALERT_WINDOW / TYPE_APPLICATION_OVERLAY permission is granted.
  Future<bool> isOverlayPermissionGranted();

  /// Launches Android settings to request system overlay permission.
  Future<bool> requestOverlayPermission();

  // ---------------------------------------------------------------------------
  // 4. Usage Statistics Permission
  // ---------------------------------------------------------------------------

  /// Checks if PACKAGE_USAGE_STATS permission is granted.
  Future<bool> isUsageStatsPermissionGranted();

  /// Launches Android Usage Access Settings screen.
  Future<bool> requestUsageStatsPermission();

  // ---------------------------------------------------------------------------
  // 5. Rule, Toggle, Schedule & Settings Synchronization
  // ---------------------------------------------------------------------------

  /// Synchronizes the full list of active blocking rules with native storage.
  Future<bool> syncRules(List<RuleModel> rules);

  /// Synchronizes per-package boolean toggles (e.g. {'com.instagram.android': true}).
  Future<bool> syncAppToggles(Map<String, bool> appToggles);

  /// Synchronizes global intervention settings (mode, hold friction, custom prompt, sound).
  Future<bool> syncInterventionConfig(InterventionConfigDto config);

  /// Synchronizes time-based active blocking schedules.
  Future<bool> syncSchedules(List<ScheduleDto> schedules);

  /// Synchronizes general app settings to the native layer.
  /// Applies restored protection as a single Android persistence operation.
  Future<bool> syncRestoredProtection({
    required List<RuleModel> rules,
    required List<ScheduleDto> schedules,
    required InterventionConfigDto config,
    required AppSettings settings,
  });

  Future<bool> updateSettings(AppSettings settings);

  /// Grants a temporary unlock window for [packageName] after friction is completed.
  Future<bool> grantTemporaryAllowance(
    String packageName, {
    int durationSeconds = 300,
  });

  // ---------------------------------------------------------------------------
  // 6. Application Discovery & Foreground Service
  // ---------------------------------------------------------------------------

  /// Retrieves list of installed applications with package names and display labels.
  Future<List<InstalledAppInfo>> getInstalledApps();

  /// Starts the persistent foreground notification service for background keep-alive.
  Future<bool> startForegroundService();

  /// Stops the persistent foreground notification service.
  Future<bool> stopForegroundService();

  /// Checks if the foreground monitoring service is currently active.
  Future<bool> isForegroundServiceRunning();

  // ---------------------------------------------------------------------------
  // 7. Realtime Metrics Query
  // ---------------------------------------------------------------------------

  /// Queries real-time session metrics directly from the background service.
  Future<RealtimeMetricsDto> getRealtimeMetrics();

  /// Reads a bounded batch without removing it from native durable storage.
  Future<bool> clearPendingBlockEvents();

  Future<List<BlockEvent>> readPendingBlockEvents({int limit = 100});

  /// Removes only events whose history was successfully saved by Flutter.
  Future<bool> acknowledgeBlockEvents(List<String> ids);

  // ---------------------------------------------------------------------------
  // 8. Event Streams
  // ---------------------------------------------------------------------------

  /// Unified broadcast stream of all platform events (blocks, service changes, battery updates).
  Stream<PlatformEvent> get eventStream;

  /// Filtered broadcast stream specifically emitting short-form video block events.
  Stream<BlockEvent> get blockEventsStream;

  /// Filtered broadcast stream emitting service connectivity/enabled status changes.
  Stream<bool> get serviceStatusStream;
}
