import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/installed_app_info.dart';
import 'package:flutter/material.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/features/app_blocker/app_blocker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

class _DiscoveryBridge extends FakePlatformBridge {
  bool installed = false;
  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async => [
    InstalledAppInfo(
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      isInstalled: installed,
    ),
  ];
}

class _LiteDiscoveryBridge extends FakePlatformBridge {
  @override
  Future<List<InstalledAppInfo>> getInstalledApps() async => const [
    InstalledAppInfo(
      packageName: 'com.facebook.lite',
      appName: 'Facebook Lite',
      isInstalled: true,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageRepository storage;
  late FakePlatformBridge bridge;
  late AppBlockerController controller;

  setUp(() async {
    storage = FakeStorageRepository()
      ..settings = AppSettings(isMasterEnabled: false);
    await storage.saveRule(
      RuleModel(
        id: 'ig',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isEnabled: true,
        blockEntireApp: true,
      ),
    );
    await storage.saveRule(
      RuleModel(
        id: 'fb',
        packageName: 'com.facebook.katana',
        appName: 'Facebook',
        isEnabled: false,
      ),
    );
    bridge = FakePlatformBridge();
    controller = AppBlockerController(bridge, storage: storage);
    await pumpEventQueue();
  });

  tearDown(() async {
    controller.dispose();
    await bridge.dispose();
  });

  test('loads persisted rules and master state', () {
    expect(controller.state.isMasterEnabled, isFalse);
    expect(controller.state.appConfigs, hasLength(2));
    expect(
      controller.state.appConfigs['com.instagram.android']!.isSurgicalOnly,
      isTrue,
    );
  });

  test('discovers Lite without replacing saved choices and syncs reels-only protection', () async {
    final liteBridge = _LiteDiscoveryBridge();
    final liteController = AppBlockerController(liteBridge, storage: storage);
    addTearDown(liteBridge.dispose);
    addTearDown(liteController.dispose);
    await pumpEventQueue();

    const lite = 'com.facebook.lite';
    expect(liteController.state.isMasterEnabled, isFalse);
    expect(
      liteController.state.appConfigs['com.facebook.katana']!.isEnabled,
      isFalse,
    );
    expect(liteController.state.appConfigs[lite]!.isSurgicalOnly, isTrue);
    expect(storage.rules[lite]!.blockEntireApp, isFalse);
    await liteController.toggleApp(lite, true);
    await liteController.setMasterToggle(true);
    expect(liteBridge.syncAppTogglesCalls.last[lite], isTrue);
    expect(
      liteBridge.syncRulesCalls.last
          .singleWhere((rule) => rule.packageName == lite)
          .blockEntireApp,
      isFalse,
    );
  });

  test('per-app toggle persists and syncs effective state', () async {
    await controller.toggleApp('com.facebook.katana', true);

    expect(storage.rules['com.facebook.katana']!.isEnabled, isTrue);
    expect(
      bridge.syncAppTogglesCalls.last['com.facebook.katana'],
      isFalse,
      reason: 'master switch is off',
    );

    await controller.setMasterToggle(true);
    expect(storage.settings.isMasterEnabled, isTrue);
    expect(bridge.syncAppTogglesCalls.last['com.facebook.katana'], isTrue);
  });

  test(
    'Facebook defaults sync as disabled under its standard package',
    () async {
      const facebook = 'com.facebook.katana';
      final defaultBridge = FakePlatformBridge();
      final defaultController = AppBlockerController(defaultBridge);
      addTearDown(defaultBridge.dispose);
      addTearDown(defaultController.dispose);
      await pumpEventQueue();

      expect(defaultController.state.appConfigs[facebook]!.isEnabled, isFalse);
      expect(defaultBridge.syncAppTogglesCalls.last[facebook], isFalse);
      final rule = defaultBridge.syncRulesCalls.last.singleWhere(
        (rule) => rule.packageName == facebook,
      );
      expect(rule.isEnabled, isFalse);
      expect(rule.blockEntireApp, isFalse);
    },
  );

  test('legacy full-app rules are normalized to surgical-only', () async {
    expect(
      controller.state.appConfigs['com.instagram.android']!.isSurgicalOnly,
      isTrue,
    );
    final synced = bridge.syncRulesCalls.last.firstWhere(
      (rule) => rule.packageName == 'com.instagram.android',
    );
    expect(synced.blockEntireApp, isFalse);

    await controller.setInterventionMode(
      'com.instagram.android',
      InterventionMode.strictBlock,
      holdDuration: 15,
    );

    final rule = storage.rules['com.instagram.android']!;
    expect(rule.interventionMode.name, 'strictBlock');
    expect(rule.holdDurationSeconds, 15);
    expect(
      controller.state.appConfigs['com.instagram.android']!.interventionMode,
      InterventionMode.strictBlock,
    );
    expect(bridge.syncRulesCalls, isNotEmpty);
  });

  test('mode changes preserve stored hold duration and mode labels', () async {
    await controller.setInterventionMode(
      'com.instagram.android',
      InterventionMode.mindfulPause,
    );
    expect(storage.rules['com.instagram.android']!.holdDurationSeconds, 7);
    expect(InterventionMode.mindfulPause.displayName, 'Pause and hold');
    expect(InterventionMode.strictBlock.displayName, 'Block feed');
  });
  testWidgets('uninstalled and legacy targets stay visible with saved rules', (
    tester,
  ) async {
    final discovery = _DiscoveryBridge();
    await storage.saveRule(
      RuleModel(
        id: 'legacy',
        packageName: 'old.legacy.app',
        appName: 'Legacy App',
        isEnabled: true,
      ),
    );
    final availabilityController = AppBlockerController(
      discovery,
      storage: storage,
    );
    addTearDown(availabilityController.dispose);
    addTearDown(discovery.dispose);
    await tester.pumpWidget(
      MaterialApp(home: AppBlockerScreen(controller: availabilityController)),
    );
    await tester.pump();
    expect(find.text('Not installed · saved rule retained'), findsOneWidget);
    expect(
      availabilityController
          .state
          .appConfigs['com.instagram.android']!
          .isEnabled,
      isTrue,
    );
    expect(availabilityController.state.appConfigs, contains('old.legacy.app'));
    expect(
      availabilityController.availabilityLabel('old.legacy.app'),
      'Legacy target · availability unknown',
    );
    expect(storage.rules['old.legacy.app']!.isEnabled, isTrue);
    expect(
      discovery.syncRulesCalls.last.map((r) => r.packageName),
      contains('old.legacy.app'),
    );
    await tester.scrollUntilVisible(find.text('Legacy App'), 250);
    expect(find.text('Legacy App'), findsOneWidget);
    discovery.installed = true;
    await availabilityController.refreshInstalledApps();
    await tester.pump();
    expect(
      availabilityController.availabilityLabel('com.instagram.android'),
      isNull,
    );
    expect(storage.rules['com.instagram.android']!.isEnabled, isTrue);
  });
}
