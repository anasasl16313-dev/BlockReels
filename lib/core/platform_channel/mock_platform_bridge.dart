import 'dart:async';

import '../models/app_settings.dart';
import '../models/installed_app_info.dart';
import '../models/rule_model.dart';
import 'dtos/intervention_config_dto.dart';
import 'dtos/platform_event.dart';
import 'dtos/realtime_metrics_dto.dart';
import 'dtos/schedule_dto.dart';
import 'platform_bridge.dart';

/// In-memory mock platform bridge enabling 100% deterministic test execution without an Android host.
class MockPlatformBridge implements PlatformBridge {
  // ---------------------------------------------------------------------------
  // Simulated Mutable State Flags
  // ---------------------------------------------------------------------------
  bool isAccessibilityEnabled = true;
  bool isBatteryOptDisabled = true;
  bool isOverlayGranted = true;
  bool isUsageStatsGranted = true;
  bool isForegroundRunning = false;

  // ---------------------------------------------------------------------------
  // Call Tracking & Verification Spies
  // ---------------------------------------------------------------------------
  final List<List<RuleModel>> syncRulesCalls = [];
  final List<Map<String, bool>> syncAppTogglesCalls = [];
  final List<InterventionConfigDto> syncInterventionConfigCalls = [];
  final List<List<ScheduleDto>> syncSchedulesCalls = [];
  final List<AppSettings> updateSettingsCalls = [];
  final List<({String packageName, int durationSeconds})>
      grantTemporaryAllowanceCalls = [];

  int requestAccessibilityCalls = 0;
  int requestBatteryOptCalls = 0;
  int requestOverlayCalls = 0;
  int requestUsageStatsCalls = 0;
  int startForegroundCalls = 0;
  int stopForegroundCalls = 0;
  int getMetricsCalls = 0;

  // ---------------------------------------------------------------------------
  // Fixtures & Configurable Outputs
  // ---------------------------------------------------------------------------
  RealtimeMetricsDto simulatedMetrics = const RealtimeMetricsDto(
    totalBlockedToday: 0,
    byApp: {},
    lastBlockedPackage: '',
    lastBlockedTimestamp: 0,
    serviceUptimeMs: 0,
  );

  List<InstalledAppInfo> simulatedInstalledApps = [
    const InstalledAppInfo(
      packageName: 'com.instagram.android',
      appName: 'Instagram',
    ),
    const InstalledAppInfo(
      packageName: 'com.google.android.youtube',
      appName: 'YouTube',
    ),
    const InstalledAppInfo(
      packageName: 'com.facebook.katana',
      appName: 'Facebook',
    ),
    const InstalledAppInfo(
      packageName: 'com.zhiliaoapp.musically',
      appName: 'TikTok',
    ),
  ];

  // ---------------------------------------------------------------------------
  // Event Streams & Controllers
  // ---------------------------------------------------------------------------
  final StreamController<PlatformEvent> _eventController =
      StreamController<PlatformEvent>.broadcast();

  // ---------------------------------------------------------------------------
  // 1. Accessibility Service Permissions & Status
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isAccessibilityServiceEnabled() async => isAccessibilityEnabled;

  @override
  Future<bool> requestAccessibilityPermission() async {
    requestAccessibilityCalls++;
    return true;
  }

  // ---------------------------------------------------------------------------
  // 2. Battery Optimization
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isBatteryOptimizationDisabled() async => isBatteryOptDisabled;

  @override
  Future<bool> requestDisableBatteryOptimization() async {
    requestBatteryOptCalls++;
    return true;
  }

  // ---------------------------------------------------------------------------
  // 3. System Overlay Permission
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isOverlayPermissionGranted() async => isOverlayGranted;

  @override
  Future<bool> requestOverlayPermission() async {
    requestOverlayCalls++;
    return true;
  }

  // ---------------------------------------------------------------------------
  // 4. Usage Statistics Permission
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isUsageStatsPermissionGranted() async => isUsageStatsGranted;

  @override
  Future<bool> requestUsageStatsPermission() async {
    requestUsageStatsCalls++;
    return true;
  }

  // ---------------------------------------------------------------------------
  // 5. Rule, Toggle, Schedule & Settings Synchronization
  // ---------------------------------------------------------------------------

  @override
  Future<bool> syncRules(List<RuleModel> rules) async {
    syncRulesCalls.add(List.from(rules));
    return true;
  }

  @override
  Future<bool> syncAppToggles(Map<String, bool> appToggles) async {
    syncAppTogglesCalls.add(Map.from(appToggles));
    return true;
  }

  @override
  Future<bool> syncInterventionConfig(InterventionConfigDto config) async {
    syncInterventionConfigCalls.add(config);
    return true;
  }

  @override
  Future<bool> syncSchedules(List<ScheduleDto> schedules) async {
    syncSchedulesCalls.add(List.from(schedules));
    return true;
  }

  @override
  Future<bool> syncRestoredProtection({
    required List<RuleModel> rules,
    required List<ScheduleDto> schedules,
    required InterventionConfigDto config,
    required AppSettings settings,
  }) async {
    return await syncRules(rules) &&
        await syncSchedules(schedules) &&
        await syncAppToggles({
          for (final rule in rules)
            rule.packageName: settings.isMasterEnabled && rule.isEnabled,
        }) &&
        await syncInterventionConfig(config) &&
        await updateSettings(settings);
  }

  @override
  Future<bool> updateSettings(AppSettings settings) async {
    updateSettingsCalls.add(settings);
    return true;
  }

  @override
  Future<bool> grantTemporaryAllowance(
    String packageName, {
    int durationSeconds = 300,
  }) async {
    grantTemporaryAllowanceCalls.add((
      packageName: packageName,
      durationSeconds: durationSeconds,
    ));
    return true;
  }

  // ---------------------------------------------------------------------------
  // 6. Application Discovery & Foreground Service
  // ---------------------------------------------------------------------------

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async =>
      List.from(simulatedInstalledApps);

  @override
  Future<bool> startForegroundService() async {
    startForegroundCalls++;
    isForegroundRunning = true;
    return true;
  }

  @override
  Future<bool> stopForegroundService() async {
    stopForegroundCalls++;
    isForegroundRunning = false;
    return true;
  }

  @override
  Future<bool> isForegroundServiceRunning() async => isForegroundRunning;

  // ---------------------------------------------------------------------------
  // 7. Realtime Metrics
  // ---------------------------------------------------------------------------

  @override
  Future<RealtimeMetricsDto> getRealtimeMetrics() async {
    getMetricsCalls++;
    return simulatedMetrics;
  }

  // ---------------------------------------------------------------------------
  // 8. Event Streams
  // ---------------------------------------------------------------------------

  final Map<String, BlockEvent> pendingBlockEvents = {};

  @override
  Future<bool> clearPendingBlockEvents() async {
    pendingBlockEvents.clear();
    return true;
  }

  @override
  Future<List<BlockEvent>> readPendingBlockEvents({int limit = 100}) async =>
      pendingBlockEvents.values.take(limit.clamp(1, 100)).toList();

  @override
  Future<bool> acknowledgeBlockEvents(List<String> ids) async {
    for (final id in ids) {
      pendingBlockEvents.remove(id);
    }
    return true;
  }

  @override
  Stream<PlatformEvent> get eventStream => _eventController.stream;

  @override
  Stream<BlockEvent> get blockEventsStream =>
      _eventController.stream.where((e) => e is BlockEvent).cast<BlockEvent>();

  @override
  Stream<bool> get serviceStatusStream => _eventController.stream
      .where((e) => e is ServiceStatusEvent)
      .cast<ServiceStatusEvent>()
      .map((e) => e.isEnabled);

  // ---------------------------------------------------------------------------
  // Simulation Helpers
  // ---------------------------------------------------------------------------

  /// Simulates an incoming raw [PlatformEvent].
  void simulatePlatformEvent(PlatformEvent event) {
    if (event is BlockEvent && event.eventId != null) {
      pendingBlockEvents[event.eventId!] = event;
    }
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Simulates a short-form video feed interception event.
  void simulateBlockEvent({
    required String packageName,
    required String appType,
    String interventionMode = 'MINDFUL_PAUSE',
    String detectionReason = 'SURGICAL_HEURISTIC',
    int? timestamp,
  }) {
    final event = BlockEvent(
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      packageName: packageName,
      appType: appType,
      interventionMode: interventionMode,
      detectionReason: detectionReason,
    );
    simulatePlatformEvent(event);
  }

  /// Simulates a change in the native Accessibility Service enabled/disabled status.
  void simulateServiceStatusChanged(bool isEnabled) {
    isAccessibilityEnabled = isEnabled;
    final event = ServiceStatusEvent(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isEnabled: isEnabled,
    );
    simulatePlatformEvent(event);
  }

  /// Simulates a change in battery optimization exemption status.
  void simulateBatteryOptChanged(bool isIgnored) {
    isBatteryOptDisabled = isIgnored;
    final event = BatteryOptEvent(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isIgnored: isIgnored,
    );
    simulatePlatformEvent(event);
  }

  /// Resets all call counts, spies, and restored default state.
  void reset() {
    pendingBlockEvents.clear();
    isAccessibilityEnabled = true;
    isBatteryOptDisabled = true;
    isOverlayGranted = true;
    isUsageStatsGranted = true;
    isForegroundRunning = false;

    syncRulesCalls.clear();
    syncAppTogglesCalls.clear();
    syncInterventionConfigCalls.clear();
    syncSchedulesCalls.clear();
    updateSettingsCalls.clear();
    grantTemporaryAllowanceCalls.clear();

    requestAccessibilityCalls = 0;
    requestBatteryOptCalls = 0;
    requestOverlayCalls = 0;
    requestUsageStatsCalls = 0;
    startForegroundCalls = 0;
    stopForegroundCalls = 0;
    getMetricsCalls = 0;

    simulatedMetrics = const RealtimeMetricsDto(
      totalBlockedToday: 0,
      byApp: {},
      lastBlockedPackage: '',
      lastBlockedTimestamp: 0,
      serviceUptimeMs: 0,
    );
  }

  /// Closes the event controller stream.
  void dispose() {
    _eventController.close();
  }
}
