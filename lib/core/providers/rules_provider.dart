import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/intervention_mode.dart';
import '../models/rule_model.dart';
import '../platform_channel/platform_bridge.dart';
import '../storage/storage_repository.dart';
import 'platform_bridge_provider.dart';
import 'storage_provider.dart';

/// StateNotifier managing per-app surgical blocking rules and synchronizing with the native bridge.
class RulesNotifier extends StateNotifier<List<RuleModel>> {
  final StorageRepository _storage;
  final PlatformBridge _bridge;

  RulesNotifier(this._storage, this._bridge) : super([]) {
    loadRules();
  }

  Future<void> loadRules() async {
    final rules = await _storage.getRules();
    state = rules;
  }

  Future<void> toggleApp(String packageName, bool isEnabled) async {
    final index = state.indexWhere((r) => r.packageName == packageName);
    if (index != -1) {
      final updatedRule = state[index].copyWith(isEnabled: isEnabled);
      final updatedList = List<RuleModel>.from(state);
      updatedList[index] = updatedRule;
      state = updatedList;

      await _storage.saveRule(updatedRule);
      await _syncBridge();
    }
  }

  Future<void> updateInterventionMode(
    String packageName,
    InterventionMode mode,
  ) async {
    final index = state.indexWhere((r) => r.packageName == packageName);
    if (index != -1) {
      final updatedRule = state[index].copyWith(interventionMode: mode);
      final updatedList = List<RuleModel>.from(state);
      updatedList[index] = updatedRule;
      state = updatedList;

      await _storage.saveRule(updatedRule);
      await _syncBridge();
    }
  }

  Future<void> updateHoldDuration(String packageName, int seconds) async {
    final index = state.indexWhere((r) => r.packageName == packageName);
    if (index != -1) {
      final updatedRule = state[index].copyWith(holdDurationSeconds: seconds);
      final updatedList = List<RuleModel>.from(state);
      updatedList[index] = updatedRule;
      state = updatedList;

      await _storage.saveRule(updatedRule);
      await _syncBridge();
    }
  }

  Future<void> updateDailyQuota(String packageName, int quotaMinutes) async {
    final index = state.indexWhere((r) => r.packageName == packageName);
    if (index != -1) {
      final updatedRule =
          state[index].copyWith(dailyQuotaMinutes: quotaMinutes);
      final updatedList = List<RuleModel>.from(state);
      updatedList[index] = updatedRule;
      state = updatedList;

      await _storage.saveRule(updatedRule);
      await _syncBridge();
    }
  }

  Future<void> updateDailyLimit(String packageName, int limit) async {
    final index = state.indexWhere((r) => r.packageName == packageName);
    if (index != -1) {
      final updatedRule = state[index].copyWith(dailyReelLimit: limit);
      final updatedList = List<RuleModel>.from(state);
      updatedList[index] = updatedRule;
      state = updatedList;

      await _storage.saveRule(updatedRule);
      await _syncBridge();
    }
  }

  Future<void> saveRule(RuleModel rule) async {
    final index = state.indexWhere((r) => r.packageName == rule.packageName);
    final updatedList = List<RuleModel>.from(state);
    if (index != -1) {
      updatedList[index] = rule;
    } else {
      updatedList.add(rule);
    }
    state = updatedList;

    await _storage.saveRule(rule);
    await _syncBridge();
  }

  Future<void> deleteRule(String id) async {
    state = state.where((r) => r.id != id && r.packageName != id).toList();
    await _storage.deleteRule(id);
    await _syncBridge();
  }

  Future<void> _syncBridge() async {
    await _bridge.syncRules(state);
    final toggles = {for (final r in state) r.packageName: r.isEnabled};
    await _bridge.syncAppToggles(toggles);
  }
}

/// Provider for the [RulesNotifier] and reactive list of [RuleModel]s.
final rulesProvider =
    StateNotifierProvider<RulesNotifier, List<RuleModel>>((ref) {
  final storage = ref.watch(storageRepositoryProvider);
  final bridge = ref.watch(platformBridgeProvider);
  return RulesNotifier(storage, bridge);
});
