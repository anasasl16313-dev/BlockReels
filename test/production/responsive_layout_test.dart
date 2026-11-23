import 'package:block_reels/features/dashboard/domain/models/dashboard_state.dart';
import 'package:block_reels/features/dashboard/presentation/widgets/kpi_metrics_row.dart';
import 'package:block_reels/features/app_blocker/app_blocker.dart';
import 'package:block_reels/features/onboarding/onboarding.dart';
import 'package:block_reels/features/pin_lock/presentation/controllers/pin_security_controller.dart';
import 'package:block_reels/features/pin_lock/presentation/screens/pin_setup_screen.dart';
import 'package:block_reels/features/schedules/schedules.dart';
import 'package:block_reels/features/settings/settings.dart';
import 'package:block_reels/features/statistics/statistics.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('KPI and PIN fit ${width.toInt()} at $scale text',
          (tester) async {
        tester.view.physicalSize = Size(width, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
              body: SafeArea(
                  child: SingleChildScrollView(
            child: KpiMetricsRow(
                state: DashboardState(
              totalBlockedToday: 1234567,
              totalTimeSavedMinutes: 123456,
              totalTimeSavedSeconds: 7407360,
            )),
          ))),
        ));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('counter_time_saved')), findsOneWidget);

        final pin = PinSecurityController();
        addTearDown(pin.dispose);
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: PinSetupScreen(controller: pin),
        ));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('btn_setup_numpad_0')));
        expect(tester.takeException(), isNull);

        final statistics = StatisticsController();
        addTearDown(statistics.dispose);
        statistics.setMockNow(DateTime(2026, 10, 28, 12));
        await statistics.ingestRecord(BlockRecord(
          id: 'large',
          packageName: 'com.instagram.android',
          appType: 'INSTAGRAM',
          timestamp: DateTime(2026, 10, 28, 11),
          estimatedTimeSavedSeconds: 999999,
        ));
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: StatisticsScreen(controller: statistics),
        ));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const Key('stat_time_saved')));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'onboarding, app controls, and schedules remain reachable at 320 × 480 and 2×',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = FakeStorageRepository();
    final bridge = FakePlatformBridge();
    addTearDown(bridge.dispose);
    final onboarding = OnboardingController(bridge, storage: storage);
    final apps = AppBlockerController(bridge, storage: storage);
    final schedules = SchedulesController(bridge, storage);
    final settingsNotifier = SettingsNotifier(storage, bridge);
    await settingsNotifier.loadSettings();
    final settings = SettingsController(storage, settingsNotifier);
    addTearDown(onboarding.dispose);
    addTearDown(apps.dispose);
    addTearDown(schedules.dispose);
    addTearDown(settings.dispose);
    addTearDown(settingsNotifier.dispose);

    Future<void> show(Widget screen) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: screen,
      ));
      expect(tester.takeException(), isNull);
    }

    onboarding.nextStep();
    await show(OnboardingWizardScreen(controller: onboarding));
    await tester.ensureVisible(find.byKey(const Key('btn_open_accessibility')));
    expect(tester.takeException(), isNull);
    await show(AppBlockerScreen(controller: apps));
    expect(tester.takeException(), isNull);
    await show(SchedulesScreen(controller: schedules));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('empty_add_schedule')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.showKeyboard(find.byKey(const Key('field_schedule_name')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('btn_save_schedule')));
    expect(tester.takeException(), isNull);
    await show(SettingsScreen(controller: settings));
    expect(tester.takeException(), isNull);
  });
}
