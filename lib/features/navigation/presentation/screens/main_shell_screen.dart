import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_blocker/app_blocker.dart';
import '../../../dashboard/dashboard.dart';
import '../../../pin_lock/pin_lock.dart';
import '../../../schedules/schedules.dart';
import '../../../settings/settings.dart';
import '../../../statistics/statistics.dart';
import '../widgets/adaptive_navigation_bar.dart';

/// Main navigation shell hosting the five primary feature tabs
/// (Dashboard, Blocker, Schedules, Insights, Settings) with Material 3
/// bottom navigation and state-preserving [IndexedStack] switching.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _restrictedAuthenticated = false;
  bool _navigationBusy = false;
  int _lifecycleEpoch = 0;
  int _securityRevision = 0;
  late final PinSecurityController _pinController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pinController = ref.read(pinSecurityControllerProvider);
    _securityRevision = _pinController.securityRevision;
    _pinController.addListener(_onPinStateChanged);
  }

  void _onPinStateChanged() {
    if (_securityRevision == _pinController.securityRevision) return;
    _securityRevision = _pinController.securityRevision;
    _clearAuthorization();
  }

  void _clearAuthorization() {
    _restrictedAuthenticated = false;
    if (mounted &&
        (_pinController.state.isPinEnabled ||
            _pinController.state.isStrictModeActive) &&
        (_currentIndex == 1 || _currentIndex == 2)) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(statisticsControllerProvider).refreshCalendar();
      unawaited(ref.read(appBlockerControllerProvider).refreshInstalledApps());
      return;
    }
    _lifecycleEpoch++;
    _pinController.invalidateAuthentication();
    _clearAuthorization();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pinController.removeListener(_onPinStateChanged);
    super.dispose();
  }

  Future<void> _selectDestination(int index) async {
    if (_navigationBusy) return;
    _navigationBusy = true;
    final epoch = _lifecycleEpoch;
    try {
      final pin = _pinController;
      final restricted = index == 1 || index == 2;
      if (restricted) await pin.ready;
      if (!mounted || epoch != _lifecycleEpoch) return;
      if (!pin.state.isPinEnabled && !pin.state.isStrictModeActive) {
        _restrictedAuthenticated = false;
      }
      if (restricted &&
          (pin.state.isPinEnabled || pin.state.isStrictModeActive) &&
          !_restrictedAuthenticated) {
        final authenticated = await authorizeRestrictionChange(context, pin);
        if (!authenticated || !mounted || epoch != _lifecycleEpoch) return;
        _restrictedAuthenticated = true;
      }
      setState(() => _currentIndex = index);
    } finally {
      _navigationBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardController = ref.watch(dashboardControllerProvider);
    final appBlockerController = ref.watch(appBlockerControllerProvider);
    final schedulesController = ref.watch(schedulesControllerProvider);
    final statisticsController = ref.watch(statisticsControllerProvider);
    final settingsController = ref.watch(settingsControllerProvider);
    final pinController = ref.watch(pinSecurityControllerProvider);

    final pages = [
      DashboardScreen(
        key: const Key('tab_dashboard'),
        controller: dashboardController,
        pinController: pinController,
        onOpenSettings: () => _selectDestination(4),
        onOpenAppControls: () => _selectDestination(1),
        onOpenSchedules: () => _selectDestination(2),
        onOpenStatistics: () => _selectDestination(3),
      ),
      AppBlockerScreen(
        key: const Key('tab_app_blocker'),
        pinController: pinController,
        controller: appBlockerController,
      ),
      SchedulesScreen(
        key: const Key('tab_schedules'),
        pinController: pinController,
        controller: schedulesController,
        protectionStatus: dashboardController.state.protectionStatus,
      ),
      StatisticsScreen(
        key: const Key('tab_statistics'),
        controller: statisticsController,
        pinController: pinController,
        protectionStatus: dashboardController.state.protectionStatus,
        onReviewProtection: () => _selectDestination(0),
        onHistoryCleared: dashboardController.refresh,
      ),
      SettingsScreen(
        key: const Key('tab_settings'),
        controller: settingsController,
        pinController: pinController,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: AdaptiveNavigationBar(
        key: const Key('main_navigation_bar'),
        selectedIndex: _currentIndex,
        onSelected: _selectDestination,
      ),
    );
  }
}
