import 'dart:async';

import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/metrics_load_state.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/theme/app_theme.dart';
import 'package:block_reels/features/dashboard/domain/models/protection_status.dart';
import 'package:block_reels/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:block_reels/features/statistics/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

class _DelayedHistoryStorage extends FakeStorageRepository {
  final Completer<List<HistoryLog>> pending = Completer<List<HistoryLog>>();
  bool shouldFail = true;

  @override
  Future<List<HistoryLog>> getHistoryLogs({
    int limit = 100,
    DateTime? since,
  }) async {
    await pending.future;
    if (shouldFail) throw StateError('read failed');
    return super.getHistoryLogs(limit: limit, since: since);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first use shows a truthful empty state and setup route',
      (tester) async {
    final controller = StatisticsController();
    addTearDown(controller.dispose);
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatisticsScreen(
        controller: controller,
        protectionStatus: const ProtectionStatus(
          kind: ProtectionStatusKind.setupRequired,
          title: 'Setup required',
          reason: 'Accessibility is off',
        ),
        onReviewProtection: () => opened = true,
      ),
    ));

    expect(find.byKey(const Key('statistics_empty')), findsOneWidget);
    expect(find.text('No recorded blocks yet'), findsOneWidget);
    expect(find.byKey(const Key('stat_focus_score')), findsNothing);
    expect(find.byKey(const Key('stat_peak_window')), findsNothing);
    await tester.tap(find.byKey(const Key('statistics_review_protection')));
    expect(opened, isTrue);
  });

  testWidgets('changing period updates values, scope, and app distribution',
      (tester) async {
    final controller = StatisticsController();
    addTearDown(controller.dispose);
    controller.setMockNow(DateTime(2026, 10, 28, 12));
    await controller.ingestRecord(BlockRecord(
      id: 'today',
      packageName: 'com.instagram.android',
      appType: 'INSTAGRAM',
      timestamp: DateTime(2026, 10, 28, 11),
      estimatedTimeSavedSeconds: 90,
    ));
    await controller.ingestRecord(BlockRecord(
      id: 'previous_month',
      packageName: 'com.google.android.youtube',
      appType: 'YOUTUBE',
      timestamp: DateTime(2026, 9, 30, 23, 59),
      estimatedTimeSavedSeconds: 30,
    ));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatisticsScreen(controller: controller),
    ));

    expect(find.text('Blocked today'), findsOneWidget);
    expect(find.text('1', findRichText: true), findsWidgets);
    expect(find.byKey(const Key('breakdown_bar_Instagram')), findsOneWidget);
    expect(find.byKey(const Key('breakdown_bar_YouTube')), findsNothing);
    expect(find.byKey(const Key('stat_focus_score')), findsNothing);
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(find.text('Blocked all time'), findsOneWidget);
    expect(find.text('Estimated time saved all time'), findsOneWidget);
    expect(find.byKey(const Key('breakdown_bar_YouTube')), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('breakdown_bar_YouTube')),
          )
          .value,
      0.5,
    );
    await tester.tap(find.text('Month'));
    await tester.pump();
    expect(find.text('Blocked this month'), findsOneWidget);
    expect(find.byKey(const Key('breakdown_bar_YouTube')), findsNothing);
  });

  testWidgets('loading, read failure, and retry are distinct', (tester) async {
    final storage = _DelayedHistoryStorage();
    final controller = StatisticsController(storage);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatisticsScreen(controller: controller),
    ));
    expect(controller.loadState, MetricsLoadState.loading);
    expect(find.byKey(const Key('statistics_loading')), findsOneWidget);
    expect(find.byKey(const Key('statistics_empty')), findsNothing);

    storage.pending.complete([]);
    await tester.pump();
    expect(controller.loadState, MetricsLoadState.error);
    expect(find.byKey(const Key('statistics_error')), findsOneWidget);
    expect(find.byKey(const Key('stat_total_blocks')), findsNothing);

    storage.shouldFail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(controller.loadState, MetricsLoadState.ready);
    expect(find.byKey(const Key('statistics_empty')), findsOneWidget);
  });

  test('legacy history still decodes without an override field', () {
    final log = HistoryLog.fromJson({
      'id': 'legacy',
      'timestamp': '2026-10-28T10:00:00',
      'appName': 'Instagram',
      'packageName': 'com.instagram.android',
      'interventionMode': InterventionMode.mindfulPause.name,
    });
    expect(log.estimatedTimeSavedSeconds, 45);
    expect(log.wasOverridden, isFalse);
    final record = BlockRecord.fromHistoryLog(log);
    final summary = StatisticsAnalyticsEngine.compute(
      records: [record],
      timeframe: StatsTimeframe.allTime,
      now: DateTime(2026, 10, 28),
    );
    expect(summary.totalBlocks, 1);
    expect(summary.focusScore, isNull);
  });

  testWidgets('clearing history refreshes dashboard metrics', (tester) async {
    final storage = FakeStorageRepository();
    final bridge = FakePlatformBridge();
    addTearDown(bridge.dispose);
    await storage.addHistoryLog(HistoryLog(
      id: 'today',
      timestamp: DateTime.now(),
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      interventionMode: InterventionMode.immediateBack,
    ));
    final dashboard = DashboardController(bridge, storage: storage);
    final statistics = StatisticsController(storage);
    addTearDown(dashboard.dispose);
    addTearDown(statistics.dispose);
    await dashboard.refresh();
    await statistics.loadFromStorage();
    expect(dashboard.state.totalBlockedToday, 1);

    await tester.pumpWidget(MaterialApp(
      home: StatisticsScreen(
        controller: statistics,
        onHistoryCleared: dashboard.refresh,
      ),
    ));
    await tester.tap(find.byKey(const Key('btn_clear_history')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn_confirm_clear_history')));
    await tester.pump();

    expect(storage.history, isEmpty);
    expect(statistics.summary.totalBlocks, 0);
    expect(dashboard.state.totalBlockedToday, 0);
    expect(dashboard.state.totalTimeSavedSeconds, 0);
  });
}
