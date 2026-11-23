import 'dart:convert';

import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/features/pin_lock/pin_lock.dart';
import 'package:block_reels/features/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';
import '../test_helpers/fake_pin_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageRepository storage;
  late FakePlatformBridge bridge;
  late ProviderContainer container;
  late SettingsController controller;
  late PinSecurityController pinController;

  setUp(() async {
    storage = FakeStorageRepository();
    bridge = FakePlatformBridge();
    container = ProviderContainer(
      overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
    await container.read(settingsProvider.notifier).loadSettings();
    controller = SettingsController(
      storage,
      container.read(settingsProvider.notifier),
    );
    pinController = PinSecurityController(
      storage,
      container.read(settingsProvider.notifier),
      FakePinWorker(),
    );
  });

  tearDown(() async {
    controller.dispose();
    pinController.dispose();
    container.dispose();
    await bridge.dispose();
  });

  test('theme, haptics, and hold duration persist through SettingsNotifier',
      () async {
    await controller.setThemeMode(AppThemeMode.amoled);
    await controller.setHaptics(false);
    await controller.setHoldDuration(8);

    expect(container.read(settingsProvider).themeMode, 'amoled');
    expect(container.read(settingsProvider).hapticFeedbackEnabled, isFalse);
    expect(container.read(settingsProvider).defaultHoldDurationSeconds, 8);
    expect(storage.settings.themeMode, 'amoled');
    expect(storage.settings.hapticFeedbackEnabled, isFalse);
    expect(storage.settings.defaultHoldDurationSeconds, 8);
    expect(bridge.syncConfigCalls.last.holdDurationSeconds, 8);
    expect(controller.settings.themeMode, AppThemeMode.amoled);
  });

  test('backup roundtrip restores rules and settings', () async {
    await storage.saveRule(
      RuleModel(
        id: 'ig',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
      ),
    );
    await controller.setThemeMode(AppThemeMode.dark);

    final backup = await controller.exportBackup();
    await storage.clearAllData();
    expect(storage.rules, isEmpty);

    final restored = await controller.importBackup(backup);
    expect(restored, isTrue);
    expect(storage.rules['com.instagram.android'], isNotNull);
    expect(storage.settings.themeMode, 'dark');
    expect(container.read(settingsProvider).themeMode, 'dark');
  });

  test('tampered backup is rejected without mutating storage', () async {
    final backup = await controller.exportBackup();
    final root = jsonDecode(backup) as Map<String, dynamic>;
    final data = root['data'] as Map<String, dynamic>;
    (data['settings'] as Map<String, dynamic>)['themeMode'] = 'light';
    final tampered = jsonEncode(root);
    final restored = await controller.importBackup(tampered);
    expect(restored, isFalse);
  });

  testWidgets('settings screen exposes real controls and privacy disclosure',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          pinController: pinController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100% On-Device Privacy'), findsOneWidget);
    final darkChoice = find.widgetWithText(ChoiceChip, 'Dark');
    await tester.tap(darkChoice);
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(darkChoice).selected, isTrue);
    expect(storage.settings.themeMode, 'dark');
    expect(find.byKey(const Key('switch_haptics')), findsOneWidget);
    expect(find.byKey(const Key('switch_foreground_service')), findsOneWidget);
    expect(find.byKey(const Key('slider_hold_duration')), findsOneWidget);

    await tester.tap(find.byKey(const Key('switch_haptics')));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(controller.settings.hapticsEnabled, isFalse);
    expect(container.read(settingsProvider).hapticFeedbackEnabled, isFalse);
    expect(storage.settings.hapticFeedbackEnabled, isFalse);

    await tester.tap(find.byKey(const Key('switch_foreground_service')));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(storage.settings.isForegroundServiceEnabled, isTrue);
    expect(bridge.foregroundRunning, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const Key('btn_import_backup')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('btn_import_backup')), findsOneWidget);
    expect(find.byKey(const Key('switch_dynamic_color')), findsNothing);
  });
  testWidgets('backup export and import require PIN when PIN lock is enabled',
      (tester) async {
    await tester.runAsync(() => pinController.setupPin('1234'));

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: controller,
          pinController: pinController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('btn_export_backup')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('btn_export_backup')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn_export_backup')));
    await settlePinUi(tester);

    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
    expect(find.text('Backup copied to clipboard'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await settlePinUi(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('btn_import_backup')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('btn_import_backup')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn_import_backup')));
    await settlePinUi(tester);

    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
  });
}
