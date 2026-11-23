import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/models/history_log.dart';
import '../../../../core/models/intervention_mode.dart';
import '../../../../core/models/metrics_load_state.dart';
import '../../../../core/models/quick_boost_window.dart';
import '../../../../core/models/schedule_model.dart';
import '../../../../core/models/usage_stats.dart';
import '../../../../core/platform_channel/dtos/platform_event.dart';
import '../../../../core/platform_channel/platform_bridge.dart';
import '../../../../core/services/block_event_recorder.dart';
import '../../../../core/storage/storage_repository.dart';
import '../../../schedules/presentation/controllers/schedules_controller.dart';
import '../../domain/models/dashboard_state.dart';
import '../../domain/models/protection_status.dart';

/// Controller coordinating dashboard live state, persisted block events, and quick controls.
class DashboardController extends ChangeNotifier {
  final PlatformBridge bridge;
  final StorageRepository? storage;
  final BlockEventRecorder? recorder;
  final Future<void> Function(String packageName, bool isEnabled)? onToggleApp;
  final Listenable? appBlockerListenable;
  final Map<String, bool> Function()? readAppToggles;
  final bool Function()? readMasterEnabled;
  final Listenable? schedulesListenable;
  final List<ScheduleModel> Function()? readSchedules;
  final bool Function()? readSynchronizationHealthy;
  final Future<void> Function()? retrySynchronization;
  final DateTime Function() _clock;
  final Duration boostTickInterval;
  final Duration protectionRefreshInterval;
  late final SchedulesController _schedulesController;
  final bool _ownsSchedulesController;

  StreamSubscription<HistoryLog>? _recordedSub;
  StreamSubscription<BlockEvent>? _blockSub;
  StreamSubscription<bool>? _serviceSub;
  StreamSubscription<PlatformEvent>? _eventSub;

  int _savedSeconds = 0;
  bool _disposed = false;
  bool _protectionInputsReady = false;
  bool _masterEnabled = true;
  List<ScheduleModel> _schedules = const [];
  int _refreshGeneration = 0;
  Timer? _boostTimer;
  Timer? _protectionTimer;
  DateTime? _boostEndsAt;
  bool _boostBusy = false;
  bool _boostUncertain = false;
  String? _boostError;
  bool get boostBusy => _boostBusy;
  bool get boostUncertain => _boostUncertain;
  String? get boostError => _boostError;

  DashboardState _state = const DashboardState();
  DashboardState get state => _state;

  DashboardController(
    this.bridge, {
    this.storage,
    this.recorder,
    this.onToggleApp,
    this.appBlockerListenable,
    this.readAppToggles,
    this.readMasterEnabled,
    this.schedulesListenable,
    this.readSchedules,
    this.readSynchronizationHealthy,
    this.retrySynchronization,
    SchedulesController? schedulesController,
    DateTime Function()? clock,
    this.boostTickInterval = const Duration(seconds: 1),
    this.protectionRefreshInterval = const Duration(seconds: 30),
  })  : _clock = clock ?? DateTime.now,
        _ownsSchedulesController = schedulesController == null {
    _schedulesController =
        schedulesController ?? SchedulesController(bridge, storage);
    appBlockerListenable?.addListener(_syncFromAppBlocker);
    schedulesListenable?.addListener(_syncFromSchedules);
    _schedulesController.addListener(_syncFromSchedules);
    _init();
  }

  void startProtectionMonitoring() {
    if (_disposed || _protectionTimer != null) return;
    _protectionTimer = Timer.periodic(
      protectionRefreshInterval,
      (_) => _updateProtectionStatus(),
    );
  }

  void stopProtectionMonitoring() {
    _protectionTimer?.cancel();
    _protectionTimer = null;
  }

  void _syncFromAppBlocker() {
    if (_disposed) return;
    final toggles = readAppToggles?.call();
    final masterEnabled = readMasterEnabled?.call();
    if (toggles == null && masterEnabled == null) return;
    if (toggles != null) {
      _state = _state.copyWith(
        activeToggles: Map<String, bool>.from(toggles),
      );
    }
    if (masterEnabled != null) {
      _masterEnabled = masterEnabled;
      _state = _state.copyWith(isMasterEnabled: masterEnabled);
    }
    _updateProtectionStatus(notify: false);
    notifyListeners();
  }

  void _syncFromSchedules() {
    if (_disposed) return;
    _schedules = _readSchedules();
    _updateProtectionStatus(notify: false);
    notifyListeners();
  }

  List<ScheduleModel> _readSchedules() =>
      readSchedules?.call() ??
      _schedulesController.allSchedules
          .map((schedule) => schedule.toCoreModel())
          .toList();

  Future<void> _init() async {
    _listenToEvents();
    await refresh();
  }

  void _listenToEvents() {
    if (recorder != null) {
      _recordedSub = recorder!.recordedLogs.listen(_applyRecordedLog);
    } else {
      _blockSub = bridge.blockEventsStream.listen(_applyLiveEvent);
    }

    _serviceSub = bridge.serviceStatusStream.listen((active) {
      if (_disposed) return;
      _state = _state.copyWith(isAccessibilityServiceActive: active);
      _updateProtectionStatus(notify: false);
      notifyListeners();
    });

    _eventSub = bridge.eventStream.listen((event) {
      if (_disposed || event is! BatteryOptEvent) return;
      _state = _state.copyWith(isBatteryOptimizationIgnored: event.isIgnored);
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    if (_boostBusy) return;
    final generation = ++_refreshGeneration;
    _protectionInputsReady = false;
    _state = _state.copyWith(metricsLoadState: MetricsLoadState.loading);
    _updateProtectionStatus();

    try {
      final serviceActive = await bridge.isAccessibilityServiceEnabled();
      final batteryIgnored = await bridge.isBatteryOptimizationDisabled();
      if (_disposed || generation != _refreshGeneration) return;

      var toggles = readAppToggles?.call() ?? _state.activeToggles;
      var masterEnabled = readMasterEnabled?.call() ?? _masterEnabled;
      var schedules = _readSchedules();
      var totalBlocks = _state.totalBlockedToday;
      var totalRecordedBlocks = _state.totalRecordedBlocks;
      var streak = _state.currentStreakDays;
      var weeklyDots = _state.weeklyStreakDots;
      String? boostName;
      DateTime? boostEnd;
      var staleBoost = false;

      if (storage != null) {
        final rules = await storage!.getRules();
        final settings = await storage!.getSettings();
        if (rules.isNotEmpty) {
          toggles = {
            for (final rule in rules) rule.packageName: rule.isEnabled
          };
        }
        final stats = await storage!.getUsageStats();
        schedules = await storage!.getSchedules();
        if (_disposed || generation != _refreshGeneration) return;
        masterEnabled = settings.isMasterEnabled;
        totalBlocks = stats.totalBlockedToday;
        totalRecordedBlocks = stats.totalBlockedLifetime;
        streak = stats.currentStreakDays;
        weeklyDots = _weeklyDotsFrom(stats.dailyTrends, _clock());
        _savedSeconds = stats.totalTimeSavedSeconds;

        final now = _clock();
        var foundQuickBoost = false;
        for (final schedule in schedules) {
          if (!isQuickBoostId(schedule.id)) continue;
          foundQuickBoost = true;
          if (boostEnd != null) continue;

          final start = _quickBoostStart(schedule);
          final end = _quickBoostEnd(schedule, now);
          final isWindowActive = start != null
              ? !now.isBefore(start) && end != null && end.isAfter(now)
              : schedule.isCurrentlyActive(now) &&
                  end != null &&
                  end.isAfter(now);
          if (isWindowActive) {
            boostName = schedule.name;
            boostEnd = end;
          }
        }
        if (boostName == null &&
            _boostEndsAt != null &&
            _boostEndsAt!.isAfter(now)) {
          boostName = _state.activeBoostSessionName;
          boostEnd = _boostEndsAt;
        }
        if (foundQuickBoost && boostEnd == null) {
          staleBoost = true;
        }
      }

      _masterEnabled = masterEnabled;
      _schedules = List<ScheduleModel>.from(schedules);
      var nextState = _state.copyWith(
        isMasterEnabled: masterEnabled,
        isAccessibilityServiceActive: serviceActive,
        isBatteryOptimizationIgnored: batteryIgnored,
        totalBlockedToday: totalBlocks,
        totalRecordedBlocks: totalRecordedBlocks,
        metricsLoadState: MetricsLoadState.ready,
        totalTimeSavedMinutes: _savedSeconds ~/ 60,
        totalTimeSavedSeconds: _savedSeconds,
        currentStreakDays: streak,
        weeklyStreakDots: weeklyDots,
        activeToggles: toggles,
      );

      if (storage != null) {
        nextState = nextState.copyWith(
          clearActiveBoost: boostName == null,
          activeBoostSessionName: boostName,
          activeBoostEndsAt: boostEnd,
          activeBoostRemainingSeconds:
              boostEnd == null ? null : _remainingSeconds(boostEnd),
        );
        _state = nextState;
        if (boostEnd != null) {
          _startBoostTimer(boostEnd);
        } else {
          _stopBoostTimer();
        }
      } else {
        _state = nextState;
      }

      _protectionInputsReady = true;
      _updateProtectionStatus(notify: false);
      notifyListeners();
      if (staleBoost) {
        unawaited(_removeQuickBoostSchedule());
      }
    } catch (_) {
      if (_disposed || generation != _refreshGeneration) return;
      _protectionInputsReady = false;
      _state = _state.copyWith(
        protectionStatus: const ProtectionStatus.unavailable(),
        metricsLoadState: MetricsLoadState.error,
      );
      notifyListeners();
    }
  }

  Future<void> requestAccessibilitySetup() async {
    await bridge.requestAccessibilityPermission();
    if (!_disposed) await refresh();
  }

  Future<void> retryProtectionStatus() async {
    await retrySynchronization?.call();
    if (_boostUncertain) {
      await _commitQuickBoost(_schedulesController.retrySync, 'resync');
    }
    await refresh();
  }

  void _applyRecordedLog(HistoryLog log) {
    _applyBlock(log);
  }

  void _applyLiveEvent(BlockEvent event) {
    final log = HistoryLog(
      id: '${event.timestamp}_${event.packageName}',
      timestamp: event.timestamp > 0
          ? DateTime.fromMillisecondsSinceEpoch(event.timestamp)
          : DateTime.now(),
      packageName: event.packageName,
      appName: event.appType.isEmpty ? event.packageName : event.appType,
      interventionMode: _modeFromWire(event.interventionMode),
      detectionReason: event.detectionReason,
    );
    _applyBlock(log);
  }

  void _applyBlock(HistoryLog log) {
    if (_disposed) return;
    _savedSeconds += log.estimatedTimeSavedSeconds;
    final now = _clock();
    final isToday = log.timestamp.year == now.year &&
        log.timestamp.month == now.month &&
        log.timestamp.day == now.day;
    _state = _state.copyWith(
      totalBlockedToday: _state.totalBlockedToday + (isToday ? 1 : 0),
      totalRecordedBlocks: _state.totalRecordedBlocks + 1,
      totalTimeSavedMinutes: _savedSeconds ~/ 60,
      totalTimeSavedSeconds: _savedSeconds,
      currentStreakDays: isToday && _state.currentStreakDays == 0
          ? 1
          : _state.currentStreakDays,
      recentEvents: [log, ..._state.recentEvents].take(5).toList(),
    );
    notifyListeners();
    if (storage != null) unawaited(refresh());
  }

  Future<void> toggleApp(String packageName, bool isEnabled) async {
    final updated = Map<String, bool>.from(_state.activeToggles);
    updated[packageName] = isEnabled;
    _state = _state.copyWith(activeToggles: updated);
    _updateProtectionStatus(notify: false);
    notifyListeners();

    final delegate = onToggleApp;
    if (delegate != null) {
      await delegate(packageName, isEnabled);
      return;
    }

    await bridge.syncAppToggles(updated);

    if (storage != null) {
      final rule = await storage!.getRule(packageName);
      if (rule != null) {
        await storage!.saveRule(rule.copyWith(isEnabled: isEnabled));
      }
    }
  }

  Future<void> activateQuickBoost(String name, int minutes) async {
    if (minutes <= 0) return;

    final now = _clock();
    final end = now.add(Duration(minutes: minutes));

    final schedule = ScheduleModel(
      id: '$quickBoostIdPrefix${now.millisecondsSinceEpoch}',
      name: name,
      daysOfWeek: [now.weekday],
      startHour: now.hour,
      startMinute: now.minute,
      endHour: end.hour,
      endMinute: end.minute,
      targetPackageNames: _state.activeToggles.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
    );
    if (await _commitQuickBoost(
      () => _schedulesController.replaceQuickBoost(schedule),
      'start',
    )) {
      _applyBoostState(name, end);
    }
  }

  Future<bool> _commitQuickBoost(
    Future<ScheduleWriteResult> Function() write,
    String action,
  ) async {
    if (_boostBusy || _disposed) return false;
    final refreshWasPending = !_protectionInputsReady;
    _refreshGeneration++;
    _boostBusy = true;
    _boostError = null;
    notifyListeners();
    try {
      if (await write() != ScheduleWriteResult.success) {
        throw StateError('Schedule sync failed');
      }
      if (_disposed) return false;
      _schedules = _readSchedules();
      _boostUncertain = false;
      _updateProtectionStatus(notify: false);
      return true;
    } catch (_) {
      if (!_disposed) {
        _boostUncertain = true;
        _boostError =
            'Could not $action the session. Protection status may be out of sync; try again.';
        _state = _state.copyWith(
            protectionStatus: const ProtectionStatus.unavailable());
      }
      return false;
    } finally {
      _boostBusy = false;
      if (!_disposed) notifyListeners();
      if (!_disposed && !_boostUncertain && refreshWasPending) {
        unawaited(refresh());
      }
    }
  }

  Future<void> endQuickBoost() => _finishBoost();

  void _applyBoostState(String name, DateTime end) {
    _boostEndsAt = end;
    _state = _state.copyWith(
      activeBoostSessionName: name,
      activeBoostEndsAt: end,
      activeBoostRemainingSeconds: _remainingSeconds(end),
    );
    notifyListeners();
    _startBoostTimer(end);
  }

  void _startBoostTimer(DateTime end) {
    _stopBoostTimer();
    _boostEndsAt = end;
    _boostTimer = Timer.periodic(boostTickInterval, (_) => _tickBoost());
  }

  void _stopBoostTimer() {
    _boostTimer?.cancel();
    _boostTimer = null;
  }

  void _tickBoost() {
    if (_disposed) return;
    final end = _boostEndsAt;
    if (end == null) {
      _stopBoostTimer();
      return;
    }

    final remaining = _remainingSeconds(end);
    if (remaining <= 0) {
      _stopBoostTimer();
      unawaited(_finishBoost());
      return;
    }
    if (remaining != _state.activeBoostRemainingSeconds) {
      _state = _state.copyWith(activeBoostRemainingSeconds: remaining);
      notifyListeners();
    }
  }

  Future<void> _finishBoost() async {
    if (!await _commitQuickBoost(
      () => _schedulesController.replaceQuickBoost(null),
      'end',
    )) return;
    _stopBoostTimer();
    _boostEndsAt = null;
    if (_state.activeBoostSessionName != null) {
      _state = _state.copyWith(clearActiveBoost: true);
      notifyListeners();
    }
  }

  Future<void> _removeQuickBoostSchedule() async {
    await _commitQuickBoost(
      () => _schedulesController.replaceQuickBoost(null),
      'clear the expired',
    );
  }

  int _remainingSeconds(DateTime end) {
    final millis = end.difference(_clock()).inMilliseconds;
    if (millis <= 0) return 0;
    return (millis / 1000).ceil();
  }

  DateTime? _quickBoostStart(ScheduleModel schedule) =>
      quickBoostStartedAt(schedule.id);

  DateTime? _quickBoostEnd(ScheduleModel schedule, DateTime now) {
    final start = _quickBoostStart(schedule);
    if (start != null) {
      return quickBoostEndsAt(
        schedule.id,
        startHour: schedule.startHour,
        startMinute: schedule.startMinute,
        endHour: schedule.endHour,
        endMinute: schedule.endMinute,
      );
    }
    if (schedule.id != quickBoostLegacyId) return null;

    final startMinutes = schedule.startHour * 60 + schedule.startMinute;
    final endMinutes = schedule.endHour * 60 + schedule.endMinute;
    if (startMinutes == endMinutes) return null;

    final nowMinutes = now.hour * 60 + now.minute;
    if (startMinutes < endMinutes || nowMinutes < endMinutes) {
      return DateTime(
        now.year,
        now.month,
        now.day,
        schedule.endHour,
        schedule.endMinute,
      );
    }

    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      schedule.endHour,
      schedule.endMinute,
    );
  }

  void setStreak(int streakDays, List<bool> dots) {
    _state = _state.copyWith(
      currentStreakDays: streakDays,
      weeklyStreakDots: dots,
    );
    notifyListeners();
  }

  void setServiceStatus(bool active) {
    _state = _state.copyWith(isAccessibilityServiceActive: active);
    _updateProtectionStatus(notify: false);
    notifyListeners();
  }

  void _updateProtectionStatus({bool notify = true}) {
    if (_disposed) return;
    final status = _boostUncertain ||
            _schedulesController.hasUnsyncedChanges ||
            readSynchronizationHealthy?.call() == false
        ? const ProtectionStatus.unavailable()
        : ProtectionStatusResolver.resolve(
            isReady: _protectionInputsReady,
            isAccessibilityServiceActive: _state.isAccessibilityServiceActive,
            isMasterEnabled: _masterEnabled,
            selectedApps: _state.activeToggles,
            schedules: _schedules,
            now: _clock(),
          );
    _state = _state.copyWith(
      protectionStatus: status,
      isMasterEnabled: _masterEnabled,
    );
    if (notify) notifyListeners();
  }

  List<bool> _weeklyDotsFrom(List<DailyTrendPoint> trends, DateTime today) {
    final monday =
        DateTime(today.year, today.month, today.day - today.weekday + 1);
    final activeDays = <int>{};
    for (final trend in trends) {
      final date = trend.date;
      final day = DateTime(date.year, date.month, date.day);
      final offset = DateTime.utc(day.year, day.month, day.day)
          .difference(DateTime.utc(monday.year, monday.month, monday.day))
          .inDays;
      if (offset >= 0 && offset < 7 && trend.count > 0) {
        activeDays.add(offset);
      }
    }
    return List<bool>.generate(7, activeDays.contains);
  }

  InterventionMode _modeFromWire(String wireName) {
    final normalized = wireName.trim().toUpperCase();
    if (normalized == 'STRICT_BLOCK' || normalized == 'STRICTBLOCK') {
      return InterventionMode.strictBlock;
    }
    if (normalized == 'MINDFUL_PAUSE' || normalized == 'MINDFULPAUSE') {
      return InterventionMode.mindfulPause;
    }
    return InterventionMode.immediateBack;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopBoostTimer();
    stopProtectionMonitoring();
    appBlockerListenable?.removeListener(_syncFromAppBlocker);
    schedulesListenable?.removeListener(_syncFromSchedules);
    _schedulesController.removeListener(_syncFromSchedules);
    if (_ownsSchedulesController) _schedulesController.dispose();
    _recordedSub?.cancel();
    _blockSub?.cancel();
    _serviceSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }
}
