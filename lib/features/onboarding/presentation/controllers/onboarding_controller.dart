import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/models/app_settings.dart';
import '../../../../core/models/intervention_mode.dart';
import '../../../../core/models/rule_model.dart';
import '../../../../core/platform_channel/dtos/intervention_config_dto.dart';
import '../../../../core/platform_channel/platform_bridge.dart';
import '../../../../core/storage/storage_repository.dart';
import '../../domain/models/onboarding_state.dart';
import '../../domain/models/onboarding_step.dart';

/// Controller coordinating onboarding progression, permissions, and initial configuration.
class OnboardingController extends ChangeNotifier {
  final PlatformBridge bridge;
  final StorageRepository? storage;

  StreamSubscription<bool>? _serviceSub;
  bool _disposed = false;

  OnboardingState _state = const OnboardingState();
  OnboardingState get state => _state;

  set state(OnboardingState newState) {
    _state = newState;
    notifyListeners();
  }

  OnboardingController(this.bridge, {this.storage}) {
    _init();
  }

  Future<void> _init() async {
    try {
      final serviceEnabled = await bridge.isAccessibilityServiceEnabled();
      final batteryIgnored = await bridge.isBatteryOptimizationDisabled();
      if (_disposed) return;

      var selectedApps = _state.selectedApps;
      var holdDuration = _state.holdDurationSeconds;
      var mode = _state.selectedInterventionMode;
      var completed = false;

      if (storage != null) {
        final settings = await storage!.getSettings();
        final rules = await storage!.getRules();
        if (_disposed) return;
        completed = settings.isOnboardingCompleted;
        holdDuration = settings.defaultHoldDurationSeconds;
        mode = _wireName(settings.defaultInterventionMode);
        if (rules.isNotEmpty) {
          selectedApps = {
            for (final rule in rules) rule.packageName: rule.isEnabled,
          };
        }
      }

      _state = _state.copyWith(
        isAccessibilityGranted: serviceEnabled,
        isBatteryOptIgnored: batteryIgnored,
        isOnboardingCompleted: completed,
        selectedApps: selectedApps,
        holdDurationSeconds: holdDuration,
        selectedInterventionMode: mode,
      );
      notifyListeners();

      _serviceSub = bridge.serviceStatusStream.listen((isEnabled) {
        if (_disposed) return;
        _state = _state.copyWith(isAccessibilityGranted: isEnabled);
        notifyListeners();
      });
    } catch (_) {
      if (!_disposed) {
        state = _state.copyWith(
            errorMessage: 'Could not check setup status. Try again.');
      }
    }
  }

  Future<void> listenToServiceState() async {
    try {
      final serviceEnabled = await bridge.isAccessibilityServiceEnabled();
      if (_disposed) return;
      state = _state.copyWith(
          isAccessibilityGranted: serviceEnabled, clearError: true);
    } catch (_) {
      if (!_disposed) {
        state = _state.copyWith(
            errorMessage: 'Could not check Accessibility. Try again.');
      }
    }
  }

  void nextStep() {
    if (_state.isBusy) return;
    if (_state.stepIndex < 3) {
      final nextIdx = _state.stepIndex + 1;
      final step = OnboardingStep.values[nextIdx];
      _state = _state.copyWith(
        stepIndex: nextIdx,
        currentStep: step,
      );
      notifyListeners();
    }
  }

  void previousStep() {
    if (_state.isBusy) return;
    if (_state.stepIndex > 0) {
      final prevIdx = _state.stepIndex - 1;
      final step = OnboardingStep.values[prevIdx];
      _state = _state.copyWith(
        stepIndex: prevIdx,
        currentStep: step,
      );
      notifyListeners();
    }
  }

  Future<void> requestAccessibility() async {
    if (_state.isBusy) return;
    state = _state.copyWith(isBusy: true, clearError: true);
    try {
      final opened = await bridge.requestAccessibilityPermission();
      if (!opened && !_disposed) {
        state = _state.copyWith(
            errorMessage: 'Could not open Accessibility settings. Try again.');
      }
    } catch (_) {
      if (!_disposed) {
        state = _state.copyWith(
            errorMessage: 'Could not open Accessibility settings. Try again.');
      }
    } finally {
      if (!_disposed) state = _state.copyWith(isBusy: false);
    }
  }

  Future<void> requestBatteryOptimization() async {
    if (_state.isBusy) return;
    state = _state.copyWith(isBusy: true, clearError: true);
    try {
      await bridge.requestDisableBatteryOptimization();
      final ignored = await bridge.isBatteryOptimizationDisabled();
      if (!_disposed) state = _state.copyWith(isBatteryOptIgnored: ignored);
    } catch (_) {
      if (!_disposed) {
        state = _state.copyWith(
            errorMessage:
                'Could not check battery settings. You can skip this optional step.');
      }
    } finally {
      if (!_disposed) state = _state.copyWith(isBusy: false);
    }
  }

  void toggleAppSelection(String packageName, bool selected) {
    if (_state.isBusy) return;
    final updated = Map<String, bool>.from(_state.selectedApps);
    updated[packageName] = selected;
    _state = _state.copyWith(selectedApps: updated);
    notifyListeners();
  }

  void selectInterventionMode(String mode, int duration) {
    _state = _state.copyWith(
      selectedInterventionMode: mode,
      holdDurationSeconds: duration,
    );
    notifyListeners();
  }

  Future<bool> completeOnboarding() async {
    if (_state.isBusy || _state.isOnboardingCompleted) return false;
    if (!_state.selectedApps.values.any((selected) => selected)) {
      state = _state.copyWith(
          errorMessage: 'Select at least one app before finishing.');
      return false;
    }
    state = _state.copyWith(isBusy: true, clearError: true);
    try {
      await listenToServiceState();
      if (_state.errorMessage != null) return false;
      final selected = Map<String, bool>.from(_state.selectedApps);
      final mode = _interventionModeFromWire(_state.selectedInterventionMode);

      var rules = storage == null ? <RuleModel>[] : await storage!.getRules();
      if (rules.isEmpty) {
        rules = selected.entries
            .map(
              (entry) => RuleModel(
                id: entry.key,
                packageName: entry.key,
                appName: _appName(entry.key),
                isEnabled: entry.value,
                interventionMode: mode,
                holdDurationSeconds: _state.holdDurationSeconds,
              ),
            )
            .toList();
      } else {
        rules = rules.map((rule) {
          if (!selected.containsKey(rule.packageName)) return rule;
          return rule.copyWith(isEnabled: selected[rule.packageName]);
        }).toList();
        for (final entry in selected.entries) {
          if (rules.any((rule) => rule.packageName == entry.key)) continue;
          rules.add(RuleModel(
            id: entry.key,
            packageName: entry.key,
            appName: _appName(entry.key),
            isEnabled: entry.value,
            interventionMode: mode,
            holdDurationSeconds: _state.holdDurationSeconds,
          ));
        }
      }

      if (storage != null) {
        for (final rule in rules) {
          await storage!.saveRule(rule);
        }
      }

      final current =
          storage == null ? AppSettings() : await storage!.getSettings();
      final settings = current.copyWith(
        isOnboardingCompleted: true,
        defaultInterventionMode: mode,
        defaultHoldDurationSeconds: _state.holdDurationSeconds,
      );
      if (!await bridge.syncRules(rules)) throw StateError('Rules sync failed');
      if (!await bridge.syncAppToggles(selected)) {
        throw StateError('App sync failed');
      }
      if (!await bridge.syncInterventionConfig(
        InterventionConfigDto(
          defaultMode: _state.selectedInterventionMode,
          holdDurationSeconds: _state.holdDurationSeconds,
          pinProtected: settings.pinLockEnabled,
          soundEnabled: settings.soundDuckingEnabled,
          hapticsEnabled: settings.hapticFeedbackEnabled,
        ),
      )) {
        throw StateError('Config sync failed');
      }
      if (!await bridge.updateSettings(settings)) {
        throw StateError('Settings sync failed');
      }
      if (storage != null) await storage!.saveSettings(settings);

      if (_disposed) return false;
      _state = _state.copyWith(
        isOnboardingCompleted: true,
        currentStep: OnboardingStep.completed,
      );
      notifyListeners();
      return true;
    } catch (_) {
      if (!_disposed) {
        state = _state.copyWith(
            errorMessage:
                'Could not save and activate your choices. Try again.');
      }
      return false;
    } finally {
      if (!_disposed) state = _state.copyWith(isBusy: false);
    }
  }

  String _wireName(InterventionMode mode) {
    switch (mode) {
      case InterventionMode.immediateBack:
        return 'AUTO_BACK';
      case InterventionMode.mindfulPause:
        return 'MINDFUL_PAUSE';
      case InterventionMode.strictBlock:
        return 'STRICT_BLOCK';
    }
  }

  InterventionMode _interventionModeFromWire(String value) {
    switch (value.toUpperCase()) {
      case 'STRICT_BLOCK':
        return InterventionMode.strictBlock;
      case 'AUTO_BACK':
        return InterventionMode.immediateBack;
      case 'MINDFUL_PAUSE':
      default:
        return InterventionMode.mindfulPause;
    }
  }

  String _appName(String packageName) {
    switch (packageName) {
      case 'com.instagram.android':
        return 'Instagram';
      case 'com.google.android.youtube':
        return 'YouTube Shorts';
      case 'com.facebook.katana':
        return 'Facebook Reels';
      case 'com.zhiliaoapp.musically':
        return 'TikTok';
      default:
        return packageName;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _serviceSub?.cancel();
    super.dispose();
  }
}
