import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/intervention_mode.dart';
import '../platform_channel/dtos/intervention_config_dto.dart';
import '../platform_channel/platform_bridge.dart';
import '../storage/storage_repository.dart';
import 'platform_bridge_provider.dart';
import 'storage_provider.dart';

/// StateNotifier managing global application settings and preferences.
class SettingsNotifier extends StateNotifier<AppSettings> {
  final StorageRepository _storage;
  final PlatformBridge _bridge;

  late Future<void> _loadFuture;
  int _loadGeneration = 0;

  SettingsNotifier(this._storage, this._bridge) : super(AppSettings()) {
    _loadFuture = _loadFromStorage();
  }

  /// Public read-only access to the current settings for controllers that must
  /// not reach into the protected [StateNotifier.state] member.
  AppSettings get currentSettings => state;
  Future<void> get ready => _loadFuture;

  Future<void> loadSettings() {
    _loadFuture = _loadFromStorage();
    return _loadFuture;
  }

  Future<void> _loadFromStorage() async {
    final generation = ++_loadGeneration;
    final settings = await _storage.getSettings();
    if (!mounted || generation != _loadGeneration) return;
    state = settings;
  }

  Future<void> _ensureLoaded() => _loadFuture;

  Future<void> toggleMasterSwitch(bool isEnabled) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(isMasterEnabled: isEnabled);
    state = updated;
    await _storage.saveSettings(updated);
    await _syncBridge();
  }

  Future<void> setThemeMode(String themeMode) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(themeMode: themeMode);
    state = updated;
    await _storage.saveSettings(updated);
  }

  Future<void> setPinLock({
    required bool enabled,
    String? pinHash,
    String? pinSalt,
  }) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(
      pinLockEnabled: enabled,
      pinHash: pinHash,
      pinSalt: pinSalt,
      failedPinAttempts: 0,
      lockoutUntil: null,
    );
    state = updated;
    await _storage.saveSettings(updated);
    await _syncBridge();
  }

  Future<void> setStrictMode(bool enabled) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(strictModeEnabled: enabled);
    state = updated;
    await _storage.saveSettings(updated);
    await _syncBridge();
  }

  Future<void> recordFailedPinAttempt() async {
    await _ensureLoaded();
    if (!mounted) return;
    final newCount = state.failedPinAttempts + 1;
    DateTime? lockout;

    // Progressive lockout per security spec: 3 attempts -> 30s,
    // 5 attempts -> 5 minutes, 10 attempts -> 30 minutes.
    if (newCount >= 10) {
      lockout = DateTime.now().add(const Duration(minutes: 30));
    } else if (newCount >= 5) {
      lockout = DateTime.now().add(const Duration(minutes: 5));
    } else if (newCount >= 3) {
      lockout = DateTime.now().add(const Duration(seconds: 30));
    }

    final updated = state.copyWith(
      failedPinAttempts: newCount,
      lockoutUntil: lockout,
    );
    state = updated;
    await _storage.saveSettings(updated);
  }

  Future<void> resetFailedPinAttempts() async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(
      failedPinAttempts: 0,
      lockoutUntil: null,
    );
    state = updated;
    await _storage.saveSettings(updated);
  }

  Future<void> setDefaultHoldDuration(int seconds) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(defaultHoldDurationSeconds: seconds);
    state = updated;
    await _storage.saveSettings(updated);
    await _syncBridge();
  }

  Future<void> setDefaultInterventionMode(InterventionMode mode) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(defaultInterventionMode: mode);
    state = updated;
    await _storage.saveSettings(updated);
    await _syncBridge();
  }

  Future<void> setBreathingTechnique(String technique) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(breathingTechnique: technique);
    state = updated;
    await _storage.saveSettings(updated);
  }

  Future<void> toggleHapticFeedback(bool enabled) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(hapticFeedbackEnabled: enabled);
    state = updated;
    await _storage.saveSettings(updated);
    await _syncBridge();
  }

  Future<void> toggleSoundDucking(bool enabled) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(soundDuckingEnabled: enabled);
    state = updated;
    await _storage.saveSettings(updated);
    await _syncBridge();
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    await _ensureLoaded();
    if (!mounted) return;
    final updated = state.copyWith(isOnboardingCompleted: completed);
    state = updated;
    await _storage.saveSettings(updated);
  }

  Future<void> toggleForegroundService(bool enabled) async {
    await _ensureLoaded();
    if (!mounted) return;

    final effectiveEnabled =
        enabled ? await _bridge.startForegroundService() : false;
    if (!enabled) {
      await _bridge.stopForegroundService();
    }
    if (!mounted) return;

    final updated = state.copyWith(
      isForegroundServiceEnabled: effectiveEnabled,
    );
    state = updated;
    await _storage.saveSettings(updated);
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _ensureLoaded();
    if (!mounted) return;
    state = settings;
    await _storage.saveSettings(settings);
    await _syncBridge();
  }

  /// Compare security fields after loading, then preserve unrelated current settings.
  Future<bool> updatePinSecurity(
      AppSettings expected, AppSettings desired) async {
    await _ensureLoaded();
    if (!mounted || !_samePinSecurity(state, expected)) return false;
    final before = state;
    final updated = _copyPinSecurity(state, desired);
    state = updated;
    try {
      await _storage.saveSettings(updated);
    } catch (_) {
      if (mounted && _samePinSecurity(state, updated)) {
        state = _copyPinSecurity(state, before);
      }
      rethrow;
    }
    if (!mounted || !_samePinSecurity(state, updated)) return false;
    await _syncBridge();
    return mounted && _samePinSecurity(state, updated);
  }

  static bool _samePinSecurity(AppSettings a, AppSettings b) =>
      a.pinLockEnabled == b.pinLockEnabled &&
      a.pinHash == b.pinHash &&
      a.pinSalt == b.pinSalt &&
      a.strictModeEnabled == b.strictModeEnabled &&
      a.failedPinAttempts == b.failedPinAttempts &&
      a.lockoutUntil == b.lockoutUntil;

  static AppSettings _copyPinSecurity(
          AppSettings current, AppSettings security) =>
      current.copyWith(
        pinLockEnabled: security.pinLockEnabled,
        pinHash: security.pinHash,
        pinSalt: security.pinSalt,
        strictModeEnabled: security.strictModeEnabled,
        failedPinAttempts: security.failedPinAttempts,
        lockoutUntil: security.lockoutUntil,
      );

  Future<void> _syncBridge() async {
    final config = InterventionConfigDto(
      defaultMode: state.defaultInterventionMode.name,
      holdDurationSeconds: state.defaultHoldDurationSeconds,
      customMessage: 'Take a deep breath. Be intentional.',
      pinProtected: state.pinLockEnabled,
      soundEnabled: state.soundDuckingEnabled,
      hapticsEnabled: state.hapticFeedbackEnabled,
    );
    await _bridge.syncInterventionConfig(config);
    await _bridge.updateSettings(state);
  }
}

/// Provider for [SettingsNotifier] and singleton [AppSettings].
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final storage = ref.watch(storageRepositoryProvider);
  final bridge = ref.watch(platformBridgeProvider);
  return SettingsNotifier(storage, bridge);
});
