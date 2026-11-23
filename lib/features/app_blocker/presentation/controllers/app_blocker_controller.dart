import 'package:flutter/foundation.dart';

import '../../../../core/models/app_settings.dart';
import '../../../../core/models/intervention_mode.dart' as core;
import '../../../../core/models/rule_model.dart';
import '../../../../core/platform_channel/dtos/intervention_config_dto.dart';
import '../../../../core/platform_channel/platform_bridge.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/storage/storage_repository.dart';
import '../../domain/models/app_blocker_state.dart';
import '../../domain/models/app_target_config_model.dart';
import '../../domain/models/intervention_mode.dart';

/// Controller managing per-app blocking configurations, master switch, and granularity.
class AppBlockerController extends ChangeNotifier {
  final PlatformBridge bridge;
  final StorageRepository? storage;
  final SettingsNotifier? settingsNotifier;

  final Map<String, RuleModel> _rules = {};
  Map<String, bool>? _installedTargets;

  String? availabilityLabel(String packageName) {
    final targets = _installedTargets;
    if (targets == null) return 'Availability unavailable';
    if (!targets.containsKey(packageName)) {
      return 'Legacy target · availability unknown';
    }
    return targets[packageName] == false
        ? 'Not installed · saved rule retained'
        : null;
  }

  Future<void> refreshInstalledApps() async {
    try {
      final apps = await bridge.getInstalledApps();
      if (_disposed) return;
      _installedTargets = {
        for (final app in apps) app.packageName: app.isInstalled,
      };
      // Existing choices and legacy rules remain intact when a new target is discovered.
      for (final app in apps.where(
        (app) => app.packageName == 'com.facebook.lite' && app.isInstalled,
      )) {
        if (_rules.isEmpty || _rules.containsKey(app.packageName)) continue;
        final rule = RuleModel(
          id: app.packageName,
          packageName: app.packageName,
          appName: app.appName,
          isEnabled: false,
          interventionMode: _settings.defaultInterventionMode,
          holdDurationSeconds: _settings.defaultHoldDurationSeconds,
        );
        await storage?.saveRule(rule);
        if (_disposed) return;
        _rules[app.packageName] = rule;
        _state = _state.copyWith(appConfigs: _configsFromRules());
      }
    } catch (_) {
      if (_disposed) return;
      _installedTargets = null;
    }
    notifyListeners();
  }

  late final void Function()? _removeSettingsListener;
  AppSettings _settings = AppSettings();
  bool _disposed = false;
  bool _initialized = false;
  bool _syncHealthy = true;
  int _syncGeneration = 0;
  bool get syncHealthy => _syncHealthy;

  AppBlockerState _state = const AppBlockerState();
  AppBlockerState get state => _state;
  int get holdDurationSeconds => _settings.defaultHoldDurationSeconds;

  AppBlockerController(this.bridge, {this.storage, this.settingsNotifier}) {
    _seedDefaults();
    _removeSettingsListener = settingsNotifier?.addListener(
      _onSettingsChanged,
      fireImmediately: false,
    );
    _init();
  }

  void _onSettingsChanged(AppSettings next) {
    final previous = _settings;
    final masterChanged = next.isMasterEnabled != _state.isMasterEnabled;
    final configChanged =
        next.defaultInterventionMode != previous.defaultInterventionMode ||
            next.defaultHoldDurationSeconds !=
                previous.defaultHoldDurationSeconds ||
            next.pinLockEnabled != previous.pinLockEnabled ||
            next.soundDuckingEnabled != previous.soundDuckingEnabled ||
            next.hapticFeedbackEnabled != previous.hapticFeedbackEnabled;
    _settings = next;
    if (!_initialized) return;
    if (masterChanged) {
      _state = _state.copyWith(isMasterEnabled: next.isMasterEnabled);
      notifyListeners();
    }
    if (masterChanged || configChanged) {
      _syncBridge();
    }
  }

  Future<void> _init() async {
    if (storage != null) {
      final rules = await storage!.getRules();
      _settings =
          settingsNotifier?.currentSettings ?? await storage!.getSettings();
      if (_disposed) return;
      _rules
        ..clear()
        ..addEntries(
          rules.map(
            (rule) => MapEntry(
              rule.packageName,
              rule.blockEntireApp ? rule.copyWith(blockEntireApp: false) : rule,
            ),
          ),
        );
      _state = AppBlockerState(
        isMasterEnabled: _settings.isMasterEnabled,
        appConfigs: _configsFromRules(),
      );
      notifyListeners();
    } else {
      _state = _state.copyWith(isMasterEnabled: _settings.isMasterEnabled);
    }
    await refreshInstalledApps();
    if (_disposed) return;
    _initialized = true;
    await _syncBridge();
  }

  void _seedDefaults() {
    final defaults = [
      RuleModel(
        id: 'com.instagram.android',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isEnabled: true,
        interventionMode: core.InterventionMode.mindfulPause,
        holdDurationSeconds: 10,
      ),
      RuleModel(
        id: 'com.google.android.youtube',
        packageName: 'com.google.android.youtube',
        appName: 'YouTube Shorts',
        isEnabled: true,
        interventionMode: core.InterventionMode.mindfulPause,
        holdDurationSeconds: 10,
      ),
      RuleModel(
        id: 'com.facebook.katana',
        packageName: 'com.facebook.katana',
        appName: 'Facebook Reels',
        isEnabled: false,
        interventionMode: core.InterventionMode.mindfulPause,
        holdDurationSeconds: 10,
      ),
      RuleModel(
        id: 'com.zhiliaoapp.musically',
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
        isEnabled: true,
        interventionMode: core.InterventionMode.mindfulPause,
        holdDurationSeconds: 10,
      ),
    ];
    for (final rule in defaults) {
      _rules[rule.packageName] = rule;
    }
    _state = AppBlockerState(
      isMasterEnabled: true,
      appConfigs: _configsFromRules(),
    );
  }

  Map<String, AppTargetConfigModel> _configsFromRules() {
    return {
      for (final rule in _rules.values)
        rule.packageName: AppTargetConfigModel(
          packageName: rule.packageName,
          appName: rule.appName,
          isEnabled: rule.isEnabled,
          isSurgicalOnly: true,
          interventionMode: _featureMode(rule.interventionMode),
          holdDurationSeconds: rule.holdDurationSeconds,
          allowChatAndDMs: rule.allowChatAndDMs,
          allowProfileGrids: rule.allowProfileGrids,
        ),
    };
  }

  void _markUnconfirmed() {
    _syncHealthy = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> toggleApp(String packageName, bool isEnabled) async {
    final rule = _rules[packageName];
    if (rule == null) return;
    _markUnconfirmed();
    final updatedRule = rule.copyWith(isEnabled: isEnabled);
    _rules[packageName] = updatedRule;
    _updateState();
    try {
      await _persistRule(updatedRule);
      await _syncBridge();
    } catch (_) {
      _markUnconfirmed();
    }
  }

  Future<void> setMasterToggle(bool isEnabled) async {
    _markUnconfirmed();
    _state = _state.copyWith(isMasterEnabled: isEnabled);
    notifyListeners();
    try {
      if (settingsNotifier != null) {
        await settingsNotifier!.toggleMasterSwitch(isEnabled);
        _settings = settingsNotifier!.currentSettings;
      } else {
        _settings = _settings.copyWith(isMasterEnabled: isEnabled);
        if (storage != null) await storage!.saveSettings(_settings);
      }
      await _syncBridge();
    } catch (_) {
      _settings = settingsNotifier?.currentSettings ?? _settings;
      _markUnconfirmed();
    }
  }

  Future<void> setInterventionMode(
    String packageName,
    InterventionMode mode, {
    int? holdDuration,
  }) async {
    final rule = _rules[packageName];
    if (rule == null) return;
    _markUnconfirmed();
    final updatedRule = rule.copyWith(
      interventionMode: _coreMode(mode),
      holdDurationSeconds: holdDuration ?? rule.holdDurationSeconds,
    );
    _rules[packageName] = updatedRule;
    _updateState();
    try {
      await _persistRule(updatedRule);
      await _syncBridge();
    } catch (_) {
      _markUnconfirmed();
    }
  }

  Future<void> retrySync() async {
    _markUnconfirmed();
    try {
      if (storage != null) {
        for (final rule in _rules.values) {
          await storage!.saveRule(rule);
        }
        await storage!.saveSettings(_settings);
      }
      await _syncBridge();
    } catch (_) {
      _markUnconfirmed();
    }
  }

  void _updateState() {
    _state = _state.copyWith(appConfigs: _configsFromRules());
    notifyListeners();
  }

  Future<void> _persistRule(RuleModel rule) async {
    if (storage != null) {
      await storage!.saveRule(rule);
    }
  }

  Future<void> _syncBridge() async {
    if (_disposed) return;
    final generation = ++_syncGeneration;
    bool current() => !_disposed && generation == _syncGeneration;
    _markUnconfirmed();
    var success = true;
    try {
      final toggles = {
        for (final rule in _rules.values)
          rule.packageName: _state.isMasterEnabled && rule.isEnabled,
      };
      success = await bridge.syncAppToggles(toggles) && success;
      if (!current()) return;
      success = await bridge.syncRules(_rules.values.toList()) && success;
      if (!current()) return;
      success = await bridge.syncInterventionConfig(
            InterventionConfigDto(
              defaultMode: _wireName(_settings.defaultInterventionMode),
              holdDurationSeconds: _settings.defaultHoldDurationSeconds,
              pinProtected: _settings.pinLockEnabled,
              soundEnabled: _settings.soundDuckingEnabled,
              hapticsEnabled: _settings.hapticFeedbackEnabled,
            ),
          ) &&
          success;
      if (!current()) return;
      success = await bridge.updateSettings(_settings) && success;
    } catch (_) {
      success = false;
    }
    if (!current()) return;
    _syncHealthy = success;
    notifyListeners();
  }

  core.InterventionMode _coreMode(InterventionMode mode) {
    switch (mode) {
      case InterventionMode.autoBack:
        return core.InterventionMode.immediateBack;
      case InterventionMode.mindfulPause:
        return core.InterventionMode.mindfulPause;
      case InterventionMode.strictBlock:
        return core.InterventionMode.strictBlock;
    }
  }

  InterventionMode _featureMode(core.InterventionMode mode) {
    switch (mode) {
      case core.InterventionMode.immediateBack:
        return InterventionMode.autoBack;
      case core.InterventionMode.mindfulPause:
        return InterventionMode.mindfulPause;
      case core.InterventionMode.strictBlock:
        return InterventionMode.strictBlock;
    }
  }

  String _wireName(core.InterventionMode mode) {
    switch (mode) {
      case core.InterventionMode.immediateBack:
        return 'AUTO_BACK';
      case core.InterventionMode.mindfulPause:
        return 'MINDFUL_PAUSE';
      case core.InterventionMode.strictBlock:
        return 'STRICT_BLOCK';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _removeSettingsListener?.call();
    super.dispose();
  }
}
