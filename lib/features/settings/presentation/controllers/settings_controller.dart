import '../../../../core/storage/validated_backup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_settings.dart';
import '../../../../core/services/restored_protection_sync.dart';
import '../../../../core/platform_channel/platform_bridge.dart';
import '../../../../core/providers/platform_bridge_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/storage_provider.dart';
import '../../../../core/storage/storage_repository.dart';
import '../../../app_blocker/app_blocker.dart';
import '../../../dashboard/dashboard.dart';
import '../../../schedules/schedules.dart';
import '../../../statistics/statistics.dart';
import '../../domain/models/app_settings_model.dart';
import '../../domain/models/app_theme_mode.dart';

class BackupSyncException implements Exception {}

/// Bridges the feature settings screen to the single core settings source.
class SettingsController extends ChangeNotifier {
  final StorageRepository _storage;
  final SettingsNotifier _notifier;
  final PlatformBridge? _bridge;
  final Future<void> Function()? _onDataRestored;
  late final void Function() _removeSettingsListener;
  AppSettingsModel _settings;

  SettingsController(
    this._storage,
    this._notifier, {
    PlatformBridge? bridge,
    Future<void> Function()? onDataRestored,
  })  : _bridge = bridge,
        _onDataRestored = onDataRestored,
        _settings =
            AppSettingsModel.fromCoreSettings(_notifier.currentSettings) {
    _removeSettingsListener = _notifier.addListener(
      _onSettingsChanged,
      fireImmediately: false,
    );
  }

  AppSettingsModel get settings => _settings;

  void _onSettingsChanged(AppSettings settings) {
    _settings = AppSettingsModel.fromCoreSettings(settings);
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
    await _notifier.setThemeMode(mode.name);
  }

  Future<void> setHaptics(bool enabled) async {
    _settings = _settings.copyWith(hapticsEnabled: enabled);
    notifyListeners();
    await _notifier.toggleHapticFeedback(enabled);
  }

  Future<void> setHoldDuration(int seconds) async {
    _settings = _settings.copyWith(defaultHoldDurationSeconds: seconds);
    notifyListeners();
    await _notifier.setDefaultHoldDuration(seconds);
  }

  Future<void> setForegroundService(bool enabled) async {
    await _notifier.toggleForegroundService(enabled);
  }

  Future<String> exportBackup() => _storage.exportBackup();

  ValidatedBackup? validateBackup(String jsonString) =>
      ValidatedBackup.parse(jsonString);

  Future<bool> importBackup(String jsonString) async {
    final backup = validateBackup(jsonString);
    return backup != null && await importValidatedBackup(backup);
  }

  Future<bool> importValidatedBackup(ValidatedBackup backup) async {
    final success = await _storage.importValidatedBackup(backup);
    if (!success) return false;

    final bridge = _bridge;
    var synced = true;
    if (bridge != null) {
      try {
        await RestoredProtectionSync.reconcile(_storage, bridge);
        final settings = await _storage.getSettings();
        if (settings.isForegroundServiceEnabled) {
          synced = await bridge.startForegroundService() && synced;
        } else {
          synced = await bridge.stopForegroundService() && synced;
        }
      } catch (_) {
        synced = false;
      }
    }
    // Dispose controllers that still hold rules from before this restore.
    await _onDataRestored?.call();
    await _notifier.loadSettings();
    if (!synced) throw BackupSyncException();
    return true;
  }

  @override
  void dispose() {
    _removeSettingsListener();
    super.dispose();
  }
}

/// Riverpod ChangeNotifierProvider for [SettingsController].
final settingsControllerProvider =
    ChangeNotifierProvider<SettingsController>((ref) {
  return SettingsController(
    ref.watch(storageRepositoryProvider),
    ref.watch(settingsProvider.notifier),
    bridge: ref.watch(platformBridgeProvider),
    onDataRestored: () async {
      ref.invalidate(appBlockerControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      ref.invalidate(schedulesControllerProvider);
      ref.invalidate(statisticsControllerProvider);
    },
  );
});
