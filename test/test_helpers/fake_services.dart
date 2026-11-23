import 'package:block_reels/core/storage/validated_backup.dart';

import 'dart:async';
import 'dart:convert';

import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/installed_app_info.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/models/usage_stats.dart';
import 'package:block_reels/core/models/whitelist_item.dart';
import 'package:block_reels/core/platform_channel/dtos/intervention_config_dto.dart';
import 'package:block_reels/core/platform_channel/dtos/platform_event.dart';
import 'package:block_reels/core/platform_channel/dtos/realtime_metrics_dto.dart';
import 'package:block_reels/core/platform_channel/dtos/schedule_dto.dart';
import 'package:block_reels/core/platform_channel/platform_bridge.dart';
import 'package:block_reels/core/storage/storage_repository.dart';
import 'package:crypto/crypto.dart';

/// In-memory production storage double for controller and integration tests.
class FakeStorageRepository implements StorageRepository {
  final historyUpdates = StreamController<HistoryLog?>.broadcast();
  @override
  Stream<HistoryLog?> get historyChanges => historyUpdates.stream;

  AppSettings settings = AppSettings();
  final Map<String, RuleModel> rules = {};
  final Map<String, ScheduleModel> schedules = {};
  final List<HistoryLog> history = [];
  final Set<String> _historyIds = {};
  final Map<String, WhitelistItem> whitelist = {};

  @override
  Future<void> init({String? customPath}) async {}

  @override
  Future<List<RuleModel>> getRules() async => rules.values.toList();

  @override
  Future<RuleModel?> getRule(String idOrPackageName) async {
    final direct = rules[idOrPackageName];
    if (direct != null) return direct;
    for (final rule in rules.values) {
      if (rule.id == idOrPackageName) return rule;
    }
    return null;
  }

  @override
  Future<void> saveRule(RuleModel rule) async {
    rules[rule.packageName] = rule;
  }

  @override
  Future<void> deleteRule(String id) async {
    rules.removeWhere((_, rule) => rule.id == id || rule.packageName == id);
  }

  @override
  Future<List<ScheduleModel>> getSchedules() async => schedules.values.toList();

  @override
  Future<ScheduleModel?> getSchedule(String id) async => schedules[id];

  @override
  Future<void> saveSchedule(ScheduleModel schedule) async {
    schedules[schedule.id] = schedule;
  }

  @override
  Future<void> deleteSchedule(String id) async {
    schedules.remove(id);
  }

  @override
  Future<AppSettings> getSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }

  @override
  Future<List<HistoryLog>> getHistoryLogs({
    int limit = 100,
    DateTime? since,
  }) async {
    final filtered = since == null
        ? history
        : history.where((log) => !log.timestamp.isBefore(since)).toList();
    final sorted = List<HistoryLog>.from(filtered)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  @override
  Future<void> addHistoryLog(HistoryLog log) async {
    history.add(log);
    _historyIds.add(log.id);
    historyUpdates.add(log);
  }

  @override
  Future<bool> addHistoryLogIfAbsent(HistoryLog log) async {
    if (_historyIds.contains(log.id)) return false;
    await addHistoryLog(log);
    return true;
  }

  @override
  Future<void> clearHistory() async {
    history.clear();
    _historyIds.clear();
    historyUpdates.add(null);
  }

  @override
  Future<List<WhitelistItem>> getWhitelistItems() async =>
      whitelist.values.toList();

  @override
  Future<void> saveWhitelistItem(WhitelistItem item) async {
    whitelist[item.id] = item;
  }

  @override
  Future<void> deleteWhitelistItem(String id) async {
    whitelist.remove(id);
  }

  @override
  Future<UsageStats> getUsageStats() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final today = history
        .where(
          (log) =>
              !log.timestamp.isBefore(startOfToday) &&
              log.timestamp.isBefore(startOfTomorrow),
        )
        .toList();
    final week =
        history.where((log) => !log.timestamp.isBefore(startOfWeek)).toList();
    final byApp = <String, int>{};
    final byHour = <int, int>{};
    for (final log in history) {
      byApp[log.appName] = (byApp[log.appName] ?? 0) + 1;
      byHour[log.timestamp.hour] = (byHour[log.timestamp.hour] ?? 0) + 1;
    }
    final trends = List<DailyTrendPoint>.generate(7, (index) {
      final day = startOfToday.subtract(Duration(days: 6 - index));
      final logs = history.where((log) {
        final date = DateTime(
          log.timestamp.year,
          log.timestamp.month,
          log.timestamp.day,
        );
        return date == day;
      }).toList();
      return DailyTrendPoint(
        date: day,
        count: logs.length,
        timeSavedSeconds: logs.fold(
          0,
          (sum, log) => sum + log.estimatedTimeSavedSeconds,
        ),
      );
    });
    final secondsSaved = history.fold(
      0,
      (sum, log) => sum + log.estimatedTimeSavedSeconds,
    );
    final streak = await calculateCurrentStreak();
    final best = await calculateBestStreak();
    return UsageStats(
      totalBlockedLifetime: history.length,
      totalBlockedToday: today.length,
      totalBlockedThisWeek: week.length,
      totalTimeSavedMinutes: secondsSaved ~/ 60,
      totalTimeSavedSeconds: secondsSaved,
      currentStreakDays: streak,
      bestStreakDays: best,
      blocksByApp: byApp,
      blocksByHour: byHour,
      dailyTrends: trends,
    );
  }

  @override
  Future<int> calculateCurrentStreak() async {
    final days = _activeDays();
    if (days.isEmpty) return 0;
    var cursor = _dateOnly(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Future<int> calculateBestStreak() async {
    final days = _activeDays().toList()..sort();
    if (days.isEmpty) return 0;
    var best = 1;
    var current = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  Set<DateTime> _activeDays() =>
      history.map((log) => _dateOnly(log.timestamp)).toSet();

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  Future<String> exportBackup() async {
    final data = {
      'rules': rules.values.map((rule) => rule.toJson()).toList(),
      'schedules': schedules.values.map((item) => item.toJson()).toList(),
      'settings': settings.toBackupJson(),
      'whitelist': whitelist.values.map((item) => item.toJson()).toList(),
      'history': history.map((log) => log.toJson()).toList(),
    };
    final encoded = jsonEncode(data);
    return jsonEncode({
      'version': 1,
      'data': data,
      'checksum': sha256.convert(utf8.encode(encoded)).toString(),
    });
  }

  @override
  Future<bool> importBackup(String jsonString) async {
    final backup = ValidatedBackup.parse(jsonString);
    return backup != null && await importValidatedBackup(backup);
  }

  @override
  String? pendingProtectionSync;
  int _restoreRevision = 0;

  @override
  Future<PendingProtectionSnapshot?> readPendingProtectionSnapshot() async {
    final revision = pendingProtectionSync;
    if (revision == null) return null;
    return (
      revision: revision,
      rules: rules.values.toList(),
      schedules: schedules.values.toList(),
      settings: settings,
    );
  }

  @override
  Future<void> acknowledgeProtectionSync(String revision) async {
    if (pendingProtectionSync == revision) pendingProtectionSync = null;
  }

  @override
  Future<bool> importValidatedBackup(ValidatedBackup backup) async {
    if (backup.rules != null) {
      rules..clear()..addEntries(backup.rules!.map((r) => MapEntry(r.packageName, r)));
    }
    if (backup.schedules != null) {
      schedules..clear()..addEntries(backup.schedules!.map((s) => MapEntry(s.id, s)));
    }
    if (backup.whitelist != null) {
      whitelist..clear()..addEntries(backup.whitelist!.map((w) => MapEntry(w.id, w)));
    }
    if (backup.history != null) {
      history..clear()..addAll(backup.history!);
      _historyIds..clear()..addAll(history.map((h) => h.id));
      historyUpdates.add(null);
    }
    final incoming = backup.settings;
    if (incoming != null) {
      settings = incoming.copyWith(
        isOnboardingCompleted: settings.isOnboardingCompleted,
        pinLockEnabled: settings.pinLockEnabled, strictModeEnabled: settings.strictModeEnabled,
        pinHash: settings.pinHash, pinSalt: settings.pinSalt,
        failedPinAttempts: settings.failedPinAttempts, lockoutUntil: settings.lockoutUntil);
    }
    pendingProtectionSync = (++_restoreRevision).toString();
    return true;
  }

  @override
  Future<void> clearAllData() async {
    settings = AppSettings();
    rules.clear();
    schedules.clear();
    history.clear();
    _historyIds.clear();
    historyUpdates.add(null);
    whitelist.clear();
  }

  @override
  Future<void> close() async {}
}

/// Deterministic production bridge double that emits real platform event types.
class FakePlatformBridge implements PlatformBridge {
  final Map<String, BlockEvent> pendingBlockEvents = {};
  final List<List<String>> acknowledgedBlockEventCalls = [];

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
    acknowledgedBlockEventCalls.add(List<String>.from(ids));
    for (final id in ids) {
      pendingBlockEvents.remove(id);
    }
    return true;
  }

  bool serviceEnabled = true;
  bool batteryOptimizationDisabled = true;
  bool overlayGranted = true;
  bool usageStatsGranted = true;
  bool foregroundRunning = false;

  final List<Map<String, bool>> syncAppTogglesCalls = [];
  final List<List<RuleModel>> syncRulesCalls = [];
  final List<List<ScheduleDto>> syncSchedulesCalls = [];
  final List<InterventionConfigDto> syncConfigCalls = [];
  final List<AppSettings> updateSettingsCalls = [];
  final List<({String packageName, int durationSeconds})> grantAllowanceCalls =
      [];
  final List<BlockEvent> emittedBlocks = [];

  final StreamController<PlatformEvent> _events =
      StreamController<PlatformEvent>.broadcast();

  @override
  Future<bool> isAccessibilityServiceEnabled() async => serviceEnabled;

  @override
  Future<bool> requestAccessibilityPermission() async => true;

  @override
  Future<bool> isBatteryOptimizationDisabled() async =>
      batteryOptimizationDisabled;

  @override
  Future<bool> requestDisableBatteryOptimization() async => true;

  @override
  Future<bool> isOverlayPermissionGranted() async => overlayGranted;

  @override
  Future<bool> requestOverlayPermission() async => true;

  @override
  Future<bool> isUsageStatsPermissionGranted() async => usageStatsGranted;

  @override
  Future<bool> requestUsageStatsPermission() async => true;

  @override
  Future<bool> syncRules(List<RuleModel> rules) async {
    syncRulesCalls.add(List<RuleModel>.from(rules));
    return true;
  }

  @override
  Future<bool> syncAppToggles(Map<String, bool> appToggles) async {
    syncAppTogglesCalls.add(Map<String, bool>.from(appToggles));
    return true;
  }

  @override
  Future<bool> syncInterventionConfig(InterventionConfigDto config) async {
    syncConfigCalls.add(config);
    return true;
  }

  @override
  Future<bool> syncSchedules(List<ScheduleDto> schedules) async {
    syncSchedulesCalls.add(List<ScheduleDto>.from(schedules));
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
    grantAllowanceCalls.add((
      packageName: packageName,
      durationSeconds: durationSeconds,
    ));
    return true;
  }

  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async => const [
        InstalledAppInfo(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
        ),
        InstalledAppInfo(
          packageName: 'com.google.android.youtube',
          appName: 'YouTube',
        ),
        InstalledAppInfo(
            packageName: 'com.facebook.katana', appName: 'Facebook'),
        InstalledAppInfo(
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
        ),
      ];

  @override
  Future<bool> startForegroundService() async {
    foregroundRunning = true;
    return true;
  }

  @override
  Future<bool> stopForegroundService() async {
    foregroundRunning = false;
    return true;
  }

  @override
  Future<bool> isForegroundServiceRunning() async => foregroundRunning;

  @override
  Future<RealtimeMetricsDto> getRealtimeMetrics() async {
    final byApp = <String, int>{};
    for (final event in emittedBlocks) {
      byApp[event.packageName] = (byApp[event.packageName] ?? 0) + 1;
    }
    return RealtimeMetricsDto(
      totalBlockedToday: emittedBlocks.length,
      byApp: byApp,
      lastBlockedPackage:
          emittedBlocks.isEmpty ? '' : emittedBlocks.last.packageName,
      lastBlockedTimestamp:
          emittedBlocks.isEmpty ? 0 : emittedBlocks.last.timestamp,
    );
  }

  @override
  Stream<PlatformEvent> get eventStream => _events.stream;

  @override
  Stream<BlockEvent> get blockEventsStream =>
      _events.stream.where((event) => event is BlockEvent).cast<BlockEvent>();

  @override
  Stream<bool> get serviceStatusStream => _events.stream
      .where((event) => event is ServiceStatusEvent)
      .map((event) => (event as ServiceStatusEvent).isEnabled);

  void emitPlatformEvent(PlatformEvent event) => _events.add(event);

  void emitBlock({
    String? eventId,
    String packageName = 'com.instagram.android',
    String appType = 'INSTAGRAM',
    String interventionMode = 'MINDFUL_PAUSE',
    DateTime? at,
  }) {
    final event = BlockEvent(
      eventId: eventId,
      timestamp: (at ?? DateTime.now()).millisecondsSinceEpoch,
      packageName: packageName,
      appType: appType,
      interventionMode: interventionMode,
    );
    emittedBlocks.add(event);
    if (eventId != null) pendingBlockEvents[eventId] = event;
    _events.add(event);
  }

  void emitServiceStatus(bool enabled) {
    serviceEnabled = enabled;
    _events.add(
      ServiceStatusEvent(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isEnabled: enabled,
      ),
    );
  }

  void emitBatteryStatus(bool ignored) {
    batteryOptimizationDisabled = ignored;
    _events.add(
      BatteryOptEvent(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isIgnored: ignored,
      ),
    );
  }

  Future<void> dispose() => _events.close();
}
