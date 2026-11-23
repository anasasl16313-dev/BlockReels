import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/features/navigation/presentation/screens/main_shell_screen.dart';
import 'package:block_reels/features/pin_lock/pin_lock.dart';
import 'package:block_reels/features/statistics/statistics.dart';
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
  late PinSecurityController pinController;
  late FakePinWorker worker;

  setUp(() async {
    storage = FakeStorageRepository();
    bridge = FakePlatformBridge();
    worker = FakePinWorker();
    container = ProviderContainer(
      overrides: [
        pinCryptoWorkerProvider.overrideWithValue(worker),
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
    await container.read(settingsProvider.notifier).loadSettings();
    pinController = container.read(pinSecurityControllerProvider);
  });

  tearDown(() async {
    container.dispose();
    await bridge.dispose();
  });

  testWidgets('PIN lock gates Blocker and Schedules tabs', (tester) async {
    await tester.runAsync(() => pinController.setupPin('1234'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainShellScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Apps'));
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);

    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
    expect(find.text('App Controls'), findsNothing);

    await tester.enterText(find.byKey(const Key('pin_input_field')), '1234');
    await tester.tap(find.text('Verify'));
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    await tester.pump();

    expect(find.byKey(const Key('pin_input_field')), findsNothing);
    expect(find.text('App Controls'), findsOneWidget);

    await tester.tap(find.text('Plans'));
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);

    expect(find.byKey(const Key('pin_input_field')), findsNothing);
    expect(find.text('Focus Schedules'), findsOneWidget);
  });

  testWidgets(
      'background and security changes clear tab authorization; harmless navigation does not',
      (tester) async {
    await tester.runAsync(() => pinController.setupPin('1234'));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainShellScreen())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    Future<void> navigate(String label) async {
      await tester.tap(find.text(label));
      await tester.runAsync(pumpEventQueue);
      await settlePinUi(tester);
      await tester.pump();
    }

    Future<void> authenticate() async {
      await tester.enterText(find.byKey(const Key('pin_input_field')), '1234');
      await tester.tap(find.text('Verify'));
      await tester.runAsync(pumpEventQueue);
      await settlePinUi(tester);
      await tester.pump();
    }

    await navigate('Apps');
    await authenticate();
    await navigate('Settings');
    expect(find.byKey(const Key('pin_input_field')), findsNothing);
    await tester.runAsync(
        () => container.read(settingsProvider.notifier).setThemeMode('dark'));
    await navigate('Plans');
    expect(find.text('Focus Schedules'), findsOneWidget);
    expect(worker.verificationCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Focus Schedules'), findsNothing);
    await navigate('Settings');
    expect(find.byKey(const Key('pin_input_field')), findsNothing);
    await navigate('Apps');
    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
    await authenticate();
    expect(worker.verificationCalls, 2);

    await tester.runAsync(() => pinController.setStrictMode(true));
    await tester.pump();
    expect(find.text('App Controls'), findsNothing);
    await navigate('Plans');
    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settlePinUi(tester);
  });

  testWidgets('clearing interception history requires PIN', (tester) async {
    await tester.runAsync(() => pinController.setupPin('1234'));
    await storage.addHistoryLog(HistoryLog(
      id: 'existing',
      timestamp: DateTime.now(),
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      interventionMode: InterventionMode.immediateBack,
    ));
    final controller = StatisticsController(storage);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          controller: controller,
          pinController: pinController,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('btn_clear_history')));
    await settlePinUi(tester);

    expect(find.text('Clear history?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn_confirm_clear_history')));
    await settlePinUi(tester);

    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
  });

  testWidgets('dashboard settings icon opens the real Settings tab',
      (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainShellScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('icon_lock_status')), findsNothing);
    await tester.tap(find.byKey(const Key('btn_open_settings')));
    await tester.pump();

    expect(find.text('Settings & Privacy'), findsOneWidget);
  });

  testWidgets('dashboard protection action keeps the Blocker PIN gate',
      (tester) async {
    await storage.saveRule(RuleModel(
      id: 'instagram',
      packageName: 'com.instagram.android',
      appName: 'Instagram',
    ));
    await tester.runAsync(() => pinController.setupPin('1234'));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainShellScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Blocking active'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_protection_action')));
    await settlePinUi(tester);

    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
    expect(find.text('App Controls'), findsNothing);
  });
}
