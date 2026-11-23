import 'dart:io';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/platform_channel/mock_platform_bridge.dart';
import 'package:block_reels/core/providers/rules_provider.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorageRepository storage;
  late MockPlatformBridge bridge;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rules_notifier_test_');
    storage = HiveStorageRepository();
    await storage.init(customPath: tempDir.path);
    bridge = MockPlatformBridge();

    container = ProviderContainer(
      overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    bridge.dispose();
    await storage.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RulesNotifier State Management Tests', () {
    test('initializes and loads seeded default rules', () async {
      final notifier = container.read(rulesProvider.notifier);
      await notifier.loadRules();

      final state = container.read(rulesProvider);
      expect(state.length, greaterThanOrEqualTo(5));
      expect(
          state.any((r) => r.packageName == 'com.instagram.android'), isTrue);
    });

    test('toggleApp modifies state, saves to storage, and syncs to bridge',
        () async {
      final notifier = container.read(rulesProvider.notifier);
      await notifier.loadRules();

      await notifier.toggleApp('com.instagram.android', false);

      final state = container.read(rulesProvider);
      final ig =
          state.firstWhere((r) => r.packageName == 'com.instagram.android');
      expect(ig.isEnabled, isFalse);

      final inStorage = await storage.getRule('com.instagram.android');
      expect(inStorage!.isEnabled, isFalse);

      expect(bridge.syncAppTogglesCalls.isNotEmpty, isTrue);
      expect(bridge.syncAppTogglesCalls.last['com.instagram.android'], isFalse);
    });

    test('updateInterventionMode modifies mode and syncs to bridge', () async {
      final notifier = container.read(rulesProvider.notifier);
      await notifier.loadRules();

      await notifier.updateInterventionMode(
        'com.google.android.youtube',
        InterventionMode.strictBlock,
      );

      final state = container.read(rulesProvider);
      final yt = state
          .firstWhere((r) => r.packageName == 'com.google.android.youtube');
      expect(yt.interventionMode, InterventionMode.strictBlock);

      final inStorage = await storage.getRule('com.google.android.youtube');
      expect(inStorage!.interventionMode, InterventionMode.strictBlock);

      expect(bridge.syncRulesCalls.isNotEmpty, isTrue);
    });

    test('updateHoldDuration updates friction timer', () async {
      final notifier = container.read(rulesProvider.notifier);
      await notifier.loadRules();

      await notifier.updateHoldDuration('com.facebook.katana', 12);

      final state = container.read(rulesProvider);
      final fb =
          state.firstWhere((r) => r.packageName == 'com.facebook.katana');
      expect(fb.holdDurationSeconds, 12);
    });

    test('saveRule and deleteRule update state and storage', () async {
      final notifier = container.read(rulesProvider.notifier);
      await notifier.loadRules();

      final newRule = RuleModel(
        id: 'new_app',
        packageName: 'com.new.app',
        appName: 'New App',
      );

      await notifier.saveRule(newRule);
      var state = container.read(rulesProvider);
      expect(state.any((r) => r.packageName == 'com.new.app'), isTrue);

      await notifier.deleteRule('new_app');
      state = container.read(rulesProvider);
      expect(state.any((r) => r.packageName == 'com.new.app'), isFalse);
    });
  });
}
