import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_bridge_provider.dart';
import 'settings_provider.dart';
import 'storage_provider.dart';

/// Immutable state container for the main Dashboard view.
class DashboardState {
  final bool isMasterEnabled;
  final bool isAccessibilityServiceActive;
  final bool isBatteryOptimizationDisabled;
  final int totalBlocksToday;
  final int totalTimeSavedMinutes;
  final int currentStreakDays;
  final String? lastBlockedApp;

  const DashboardState({
    this.isMasterEnabled = true,
    this.isAccessibilityServiceActive = false,
    this.isBatteryOptimizationDisabled = false,
    this.totalBlocksToday = 0,
    this.totalTimeSavedMinutes = 0,
    this.currentStreakDays = 0,
    this.lastBlockedApp,
  });

  DashboardState copyWith({
    bool? isMasterEnabled,
    bool? isAccessibilityServiceActive,
    bool? isBatteryOptimizationDisabled,
    int? totalBlocksToday,
    int? totalTimeSavedMinutes,
    int? currentStreakDays,
    String? lastBlockedApp,
  }) {
    return DashboardState(
      isMasterEnabled: isMasterEnabled ?? this.isMasterEnabled,
      isAccessibilityServiceActive:
          isAccessibilityServiceActive ?? this.isAccessibilityServiceActive,
      isBatteryOptimizationDisabled:
          isBatteryOptimizationDisabled ?? this.isBatteryOptimizationDisabled,
      totalBlocksToday: totalBlocksToday ?? this.totalBlocksToday,
      totalTimeSavedMinutes:
          totalTimeSavedMinutes ?? this.totalTimeSavedMinutes,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      lastBlockedApp: lastBlockedApp ?? this.lastBlockedApp,
    );
  }
}

/// StateNotifier coordinating live metrics, service health, and master toggles for the dashboard.
class DashboardNotifier extends StateNotifier<DashboardState> {
  final Ref _ref;
  StreamSubscription? _blockSub;
  StreamSubscription? _statusSub;

  DashboardNotifier(this._ref) : super(const DashboardState()) {
    _listenToEvents();
    refresh();
  }

  void _listenToEvents() {
    final bridge = _ref.read(platformBridgeProvider);

    _blockSub = bridge.blockEventsStream.listen((event) async {
      final current = state;
      state = current.copyWith(
        totalBlocksToday: current.totalBlocksToday + 1,
        totalTimeSavedMinutes: current.totalTimeSavedMinutes + 1,
        lastBlockedApp:
            event.appType.isNotEmpty ? event.appType : event.packageName,
      );
    });

    _statusSub = bridge.serviceStatusStream.listen((isActive) {
      state = state.copyWith(isAccessibilityServiceActive: isActive);
    });
  }

  Future<void> refresh() async {
    final storage = _ref.read(storageRepositoryProvider);
    final bridge = _ref.read(platformBridgeProvider);
    final settings = _ref.read(settingsProvider);

    final isServiceActive = await bridge.isAccessibilityServiceEnabled();
    final isBatteryDisabled = await bridge.isBatteryOptimizationDisabled();
    final stats = await storage.getUsageStats();

    state = state.copyWith(
      isMasterEnabled: settings.isMasterEnabled,
      isAccessibilityServiceActive: isServiceActive,
      isBatteryOptimizationDisabled: isBatteryDisabled,
      totalBlocksToday: stats.totalBlockedToday,
      totalTimeSavedMinutes: stats.totalTimeSavedMinutes,
      currentStreakDays: stats.currentStreakDays,
    );
  }

  Future<void> toggleMasterSwitch(bool value) async {
    await _ref.read(settingsProvider.notifier).toggleMasterSwitch(value);
    state = state.copyWith(isMasterEnabled: value);
  }

  @override
  void dispose() {
    _blockSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}

/// Provider for [DashboardNotifier] and reactive [DashboardState].
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref);
});
