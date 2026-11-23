import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/theme/app_theme.dart';
import 'package:block_reels/features/navigation/presentation/screens/main_shell_screen.dart';
import 'package:block_reels/features/onboarding/onboarding.dart';
import 'package:block_reels/features/pin_lock/pin_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';
import '../test_helpers/visual_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDeviceTestFonts);

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
          'all screens at $width × 480, text $scale, safe edges and keyboard',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 480);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        try {
          final storage = FakeStorageRepository();
          final bridge = FakePlatformBridge();
          final now = DateTime.now();
          for (var i = 0; i < 3; i++) {
            await storage.addHistoryLog(HistoryLog(
              id: '$i',
              timestamp: now,
              packageName: 'com.instagram.android',
              appName: i == 0 ? 'YouTube' : 'Instagram',
              interventionMode: InterventionMode.mindfulPause,
              estimatedTimeSavedSeconds: 987654321,
            ));
          }
          await storage.saveSchedule(ScheduleModel(
            id: 'work',
            name: 'Morning work and study',
            daysOfWeek: [1, 2, 3, 4, 5],
            startHour: 9,
            startMinute: 0,
            endHour: 17,
            endMinute: 30,
            targetPackageNames: const [],
          ));
          final container = ProviderContainer(overrides: [
            storageRepositoryProvider.overrideWithValue(storage),
            platformBridgeProvider.overrideWithValue(bridge),
          ]);
          addTearDown(() async {
            container.dispose();
            await bridge.dispose();
          });
          await container.read(settingsProvider.notifier).loadSettings();
          final boundary = GlobalKey();
          final previews =
              (width == 320 && scale == 2) || (width == 430 && scale == 1);
          final suffix = '${width.toInt()}-${scale.toStringAsFixed(1)}';

          Future<void> check([String? preview]) async {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));
            expect(tester.takeException(), isNull, reason: preview);
            if (previews && preview != null) {
              await saveLayoutPreview(
                  tester, find.byKey(boundary), '$preview-$suffix');
            }
          }

          Future<void> show(Widget screen) async {
            await tester.pumpWidget(UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                  key: boundary,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.lightTheme,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: screen,
                  )),
            ));
            await check();
          }

          Future<void> scrollPage() async {
            final scrollable = find.byType(Scrollable).first;
            final state = tester.state<ScrollableState>(scrollable);
            state.position.jumpTo(0);
            for (var step = 0; step < 100; step++) {
              await tester.pump();
              expect(tester.takeException(), isNull);
              final position = state.position;
              if (position.pixels >= position.maxScrollExtent) break;
              position.jumpTo(
                  (position.pixels + position.viewportDimension * .9)
                      .clamp(0, position.maxScrollExtent));
            }
            await check();
            state.position.jumpTo(0);
            await check();
          }

          await show(const MainShellScreen());
          await check('dashboard');
          await tester.scrollUntilVisible(
              find.byKey(const Key('counter_time_saved')), 100);
          await check('dashboard-metrics');
          await scrollPage();
          for (var index = 1; index < 5; index++) {
            final destination = find.byKey(Key('destination_$index'));
            expect(destination.hitTestable(), findsOneWidget);
            await tester.tap(destination);
            await check(
                ['home', 'apps', 'schedules', 'statistics', 'settings'][index]);
            if (index == 3) {
              await tester.scrollUntilVisible(
                  find.byKey(const Key('stat_time_saved')), 100);
              await check('statistics-metrics');
            }
            await scrollPage();
          }
          // Labels retain the requested text scale and fit their cells.
          for (final label in ['Home', 'Apps', 'Plans', 'Stats', 'Settings']) {
            final text = find.descendant(
                of: find.byKey(const Key('main_navigation_bar')),
                matching: find.text(label));
            final paragraph = tester.renderObject<RenderParagraph>(text);
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(paragraph.textScaler.scale(12), scale * 12);
          }

          await tester.tap(find.byKey(const Key('destination_2')));
          await check();
          await tester.tap(find.byKey(const Key('fab_add_schedule')));
          await check('schedule-editor');
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          tester.view.padding = const FakeViewPadding(top: 24);
          await tester
              .showKeyboard(find.byKey(const Key('field_schedule_name')));
          await check();
          await tester
              .ensureVisible(find.byKey(const Key('field_schedule_name')));
          await check('schedule-keyboard');
          expect(find.byKey(const Key('field_schedule_name')).hitTestable(),
              findsOneWidget);
          expect(find.byKey(const Key('btn_save_schedule')).hitTestable(),
              findsOneWidget);
          await tester.tap(find.byKey(const Key('btn_save_schedule')));
          await check();
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('btn_save_schedule')), findsNothing);
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          tester.view.resetViewInsets();
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);

          final onboarding = OnboardingController(bridge, storage: storage);
          addTearDown(onboarding.dispose);
          await show(OnboardingWizardScreen(controller: onboarding));
          for (var step = 0; step < 4; step++) {
            await check('onboarding-$step');
            await scrollPage();
            final actionKey = [
              'btn_get_started',
              'btn_next_step_2',
              'btn_skip_battery_opt',
              'btn_start_focusing',
            ][step];
            await tester.ensureVisible(find.byKey(Key(actionKey)));
            await check();
            expect(find.byKey(Key(actionKey)).hitTestable(), findsOneWidget);
            if (step < 3) onboarding.nextStep();
          }
          await tester
              .ensureVisible(find.byKey(const Key('btn_start_focusing')));
          await check('onboarding-finish');
          expect(find.byKey(const Key('btn_start_focusing')).hitTestable(),
              findsOneWidget);

          final pin = PinSecurityController();
          addTearDown(pin.dispose);
          await show(PinSetupScreen(controller: pin));
          await check('pin-setup');
          await tester
              .ensureVisible(find.byKey(const Key('btn_setup_numpad_0')));
          await check('pin-setup-keypad');
          expect(find.byKey(const Key('btn_setup_numpad_0')).hitTestable(),
              findsOneWidget);
          expect(find.bySemanticsLabel('Delete last digit'), findsOneWidget);
          await show(PinEntryWidget(controller: pin, onResult: (_) {}));
          await check('pin-entry');
          await tester.ensureVisible(find.byKey(const Key('btn_numpad_0')));
          await check('pin-entry-keypad');
          expect(find.bySemanticsLabel('Delete last digit'), findsOneWidget);

          await show(Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                        onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => PinEntryDialog(
                                  onVerifyPin: (pin) => pin == '1234',
                                  onAuthenticated: () {},
                                )),
                        child: const Text('Authenticate'),
                      ))));
          await tester.tap(find.text('Authenticate'));
          await check();
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          tester.view.padding = const FakeViewPadding(top: 24);
          await tester.enterText(
              find.byKey(const Key('pin_input_field')), '1234');
          await check();
          await tester.ensureVisible(find.byKey(const Key('pin_input_field')));
          await check('pin-keyboard');
          expect(find.byKey(const Key('pin_input_field')).hitTestable(),
              findsOneWidget);
          expect(find.byKey(const Key('pin_submit_button')).hitTestable(),
              findsOneWidget);
          await tester.tap(find.byKey(const Key('pin_submit_button')));
          await check();
          expect(find.byKey(const Key('pin_submit_button')), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
