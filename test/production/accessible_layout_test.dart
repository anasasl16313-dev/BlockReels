import 'dart:ui' show Tristate;

import 'package:block_reels/core/theme/app_theme.dart';
import 'package:block_reels/core/widgets/adaptive_metrics.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/features/app_blocker/app_blocker.dart';
import 'package:block_reels/features/navigation/presentation/screens/main_shell_screen.dart';
import 'package:block_reels/features/navigation/presentation/widgets/adaptive_navigation_bar.dart';
import 'package:block_reels/features/schedules/schedules.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/visual_test_support.dart';
import '../test_helpers/fake_services.dart';

void main() {
  setUpAll(loadDeviceTestFonts);

  testWidgets('navigation has named 48px targets, selection and keyboard order',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      var selected = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
          builder: (context, setState) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: AdaptiveNavigationBar(
              selectedIndex: selected,
              onSelected: (index) => setState(() => selected = index),
            ),
          ),
        )),
      ));
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Dashboard'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue);
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('App controls'))
              .flagsCollection
              .isButton,
          isTrue);
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Schedules'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (var index = 0; index < 5; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(selected, index);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('large metrics keep units on one line and full spoken values',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      for (final number in [42, 1234567, 9876543210, 9223372036854775807]) {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
              body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: MetricValue(
                  number: number,
                  unit: 'min',
                  semanticLabel: '$number minutes estimated',
                  style: const TextStyle(fontSize: 28),
                  textKey: const Key('metric')),
            ),
          )),
        ));
        expect(
            find.bySemanticsLabel('$number minutes estimated'), findsOneWidget);
        final paragraph = tester
            .renderObject<RenderParagraph>(find.byKey(const Key('metric')));
        final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler)
          ..layout();
        expect(painter.width, lessThanOrEqualTo(paragraph.size.width));
        expect(paragraph.text.toPlainText(), endsWith('\u00a0min'));
        expect(paragraph.textScaler.scale(28), 56);
        painter.dispose();
        expect(tester.takeException(), isNull);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('app control switches have names and expose their state',
      (tester) async {
    final bridge = FakePlatformBridge();
    final controller = AppBlockerController(bridge);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(MaterialApp(
        home: AppBlockerScreen(controller: controller),
      ));
      await tester.pump();
      final master = tester
          .getSemantics(find.bySemanticsLabel('Master protection switch'));
      final app = tester.getSemantics(
          find.bySemanticsLabel('Select Instagram for manual blocking'));
      expect(master.flagsCollection.isToggled, Tristate.isTrue);
      expect(app.flagsCollection.isToggled, Tristate.isTrue);
      expect(master.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(app.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
      controller.dispose();
      await bridge.dispose();
    }
  });

  testWidgets('first-use setup actions are reachable at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bridge = FakePlatformBridge()..serviceEnabled = false;
    final storage = FakeStorageRepository();
    final container = ProviderContainer(overrides: [
      platformBridgeProvider.overrideWithValue(bridge),
      storageRepositoryProvider.overrideWithValue(storage),
    ]);
    addTearDown(() async {
      container.dispose();
      await bridge.dispose();
    });
    await container.read(settingsProvider.notifier).loadSettings();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const MainShellScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(find.text('Set up protection'), 100);
    await tester.ensureVisible(find.text('Set up protection'));
    await tester.pump();
    expect(find.text('Set up protection').hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('dashboard_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('destination_3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.scrollUntilVisible(
        find.byKey(const Key('statistics_review_protection')), 100);
    await tester
        .ensureVisible(find.byKey(const Key('statistics_review_protection')));
    await tester.pump();
    expect(find.byKey(const Key('statistics_review_protection')).hitTestable(),
        findsOneWidget);
    expect(find.byKey(const Key('statistics_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('schedule time picker is usable on a short screen at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bridge = FakePlatformBridge();
    final controller = SchedulesController(bridge);
    addTearDown(() async {
      controller.dispose();
      await bridge.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: SchedulesScreen(controller: controller),
    ));
    await tester.tap(find.byKey(const Key('empty_add_schedule')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const Key('btn_schedule_start_time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_schedule_start_time')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('OK').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Cancel').hitTestable());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
