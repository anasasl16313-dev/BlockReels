import 'dart:async';

import 'package:block_reels/features/app_blocker/app_blocker.dart';
import 'package:block_reels/features/dashboard/dashboard.dart';
import 'package:block_reels/features/schedules/schedules.dart';
import 'package:block_reels/features/statistics/statistics.dart';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart' as core;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/fake_services.dart';

class DelayedStatusBridge extends FakePlatformBridge {
  final status = Completer<bool>();
  @override
  Future<bool> isAccessibilityServiceEnabled() => status.future;
}

void main() {
  testWidgets('session start waits until app selections are known',
      (tester) async {
    final bridge = DelayedStatusBridge();
    final controller =
        DashboardController(bridge, storage: FakeStorageRepository());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AnimatedBuilder(
      animation: controller,
      builder: (_, __) => QuickBoostRow(controller: controller),
    ))));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('chip_boost_25m')))
            .onPressed,
        isNull);
    bridge.status.complete(true);
    await tester.pump();
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('chip_boost_25m')))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await bridge.dispose();
  });

  testWidgets('empty activity and schedules offer their useful actions',
      (tester) async {
    var viewed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RecentInterceptionsList(
      state: const DashboardState(),
      onViewStatistics: () => viewed = true,
    ))));
    await tester.tap(find.text('View statistics'));
    expect(viewed, isTrue);
    final bridge = FakePlatformBridge();
    final controller = SchedulesController(bridge);
    var added = false;
    await tester.pumpWidget(MaterialApp(
        home: SchedulesScreen(
            controller: controller, onAddTap: () => added = true)));
    await tester.tap(find.byKey(const Key('empty_add_schedule')));
    expect(added, isTrue);
    expect(find.byKey(const Key('fab_add_schedule')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await bridge.dispose();
  });

  testWidgets('empty statistics can return to protection', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = StatisticsController();
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: StatisticsScreen(
          controller: controller,
          onReviewProtection: () => opened = true,
        )));
    await tester
        .ensureVisible(find.byKey(const Key('statistics_view_protection')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('statistics_view_protection')));
    expect(opened, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('empty period can open all recorded activity', (tester) async {
    final controller = StatisticsController();
    controller.setMockNow(DateTime(2026, 5, 12, 12));
    await controller.ingestRecord(BlockRecord(
        id: 'old',
        packageName: 'com.instagram.android',
        appType: 'Instagram',
        timestamp: DateTime(2026, 5, 10, 10)));
    await tester.pumpWidget(
        MaterialApp(home: StatisticsScreen(controller: controller)));
    expect(find.byKey(const Key('statistics_view_all')), findsOneWidget);
    await tester.tap(find.byKey(const Key('statistics_view_all')));
    await tester.pump();
    expect(find.byKey(const Key('stat_total_blocks')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
      'recent activity shows the app and local time without punitive copy',
      (tester) async {
    final timestamp = DateTime(2026, 5, 12, 10, 30);
    final state = DashboardState(recentEvents: [
      HistoryLog(
          id: 'one',
          timestamp: timestamp,
          packageName: 'app',
          appName: 'Instagram',
          interventionMode: core.InterventionMode.immediateBack)
    ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RecentInterceptionsList(state: state))));
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.textContaining('Feed blocked ·'), findsOneWidget);
    expect(find.textContaining('10:30'), findsOneWidget);
    expect(find.textContaining('intercepted'), findsNothing);
  });

  testWidgets(
      'app options expand without motion when reduced motion is enabled',
      (tester) async {
    final bridge = FakePlatformBridge();
    final controller = AppBlockerController(bridge);
    addTearDown(() async {
      controller.dispose();
      await bridge.dispose();
    });
    final config = controller.state.appConfigs['com.instagram.android']!;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              child: AppTargetCard(config: config, controller: controller))),
    ));
    expect(
        find.byKey(const Key('dropdown_com.instagram.android')), findsNothing);
    expect(find.textContaining('Mode:'), findsOneWidget);
    expect(find.byType(AnimatedSize), findsNothing);
    await tester.tap(find.byKey(const Key('details_com.instagram.android')));
    await tester.pump();
    expect(find.byKey(const Key('dropdown_com.instagram.android')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'active focus session and end action remain accessible at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bridge = FakePlatformBridge();
    final storage = FakeStorageRepository();
    final controller = DashboardController(bridge, storage: storage);
    addTearDown(() async {
      controller.dispose();
      await bridge.dispose();
    });
    await tester.runAsync(controller.refresh);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) => QuickBoostRow(controller: controller)))),
    ));
    await tester.tap(find.byKey(const Key('chip_boost_25m')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('button_end_boost')));
    await tester.pump();
    expect(find.byKey(const Key('button_end_boost')).hitTestable(),
        findsOneWidget);
    expect(
        find.byKey(const Key('text_active_boost_remaining')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('button_end_boost')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('banner_active_boost')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
