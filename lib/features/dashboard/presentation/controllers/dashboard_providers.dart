import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/block_event_recorder_provider.dart';
import '../../../../core/providers/platform_bridge_provider.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../app_blocker/presentation/controllers/app_blocker_providers.dart';
import '../../../schedules/presentation/controllers/schedules_controller.dart';
import 'dashboard_controller.dart';

/// Riverpod ChangeNotifierProvider for [DashboardController].
final dashboardControllerProvider =
    ChangeNotifierProvider<DashboardController>((ref) {
  final appBlocker = ref.watch(appBlockerControllerProvider.notifier);
  final schedules = ref.watch(schedulesControllerProvider.notifier);
  return DashboardController(
    ref.watch(platformBridgeProvider),
    storage: ref.watch(storageRepositoryProvider),
    recorder: ref.watch(blockEventRecorderProvider),
    onToggleApp: appBlocker.toggleApp,
    appBlockerListenable: appBlocker,
    readAppToggles: () => {
      for (final entry in appBlocker.state.appConfigs.entries)
        entry.key: entry.value.isEnabled,
    },
    readMasterEnabled: () => appBlocker.state.isMasterEnabled,
    schedulesController: schedules,
    readSynchronizationHealthy: () =>
        appBlocker.syncHealthy && !schedules.hasUnsyncedChanges,
    retrySynchronization: () async {
      if (!appBlocker.syncHealthy) await appBlocker.retrySync();
      if (schedules.hasUnsyncedChanges) await schedules.retrySync();
    },
  );
});
