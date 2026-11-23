import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/services/block_event_recorder.dart';
import 'package:block_reels/features/dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageRepository storage;
  late FakePlatformBridge bridge;
  late BlockEventRecorder recorder;
  late DashboardController controller;

  setUp(() async {
    storage = FakeStorageRepository();
    bridge = FakePlatformBridge();
    await storage.saveRule(
      RuleModel(
        id: 'ig',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isEnabled: false,
      ),
    );
    await storage.saveRule(
      RuleModel(
        id: 'yt',
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        isEnabled: true,
      ),
    );
    await storage.addHistoryLog(
      HistoryLog(
        id: 'existing',
        timestamp: DateTime.now(),
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        interventionMode: InterventionMode.mindfulPause,
        estimatedTimeSavedSeconds: 120,
      ),
    );
    recorder = BlockEventRecorder(bridge, storage)..start();
    controller = DashboardController(
      bridge,
      storage: storage,
      recorder: recorder,
    );
    await controller.refresh();
    await pumpEventQueue();
  });

  tearDown(() async {
    controller.dispose();
    await recorder.dispose();
    await bridge.dispose();
  });

  test('refresh hydrates rules, stats, time saved, and permission status',
      () async {
    expect(controller.state.isAccessibilityServiceActive, isTrue);
    expect(controller.state.isBatteryOptimizationIgnored, isTrue);
    expect(controller.state.totalBlockedToday, 1);
    expect(controller.state.totalTimeSavedMinutes, 2);
    expect(
      controller.state.activeToggles['com.instagram.android'],
      isFalse,
    );
  });

  test('native event is persisted once and updates the dashboard', () async {
    bridge.emitBlock(
      packageName: 'com.zhiliaoapp.musically',
      appType: 'TIKTOK',
    );
    await pumpEventQueue();

    expect(storage.history, hasLength(2));
    expect(controller.state.totalBlockedToday, 2);
    expect(controller.state.recentEvents.first.appName, 'TikTok');
    expect(controller.state.totalTimeSavedMinutes, 2);
  });

  test(
      'dashboard daily count ignores older events while lifetime estimate grows',
      () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    bridge.emitBlock(at: yesterday);
    await pumpEventQueue();

    expect(controller.state.totalBlockedToday, 1);
    expect(controller.state.totalRecordedBlocks, 2);
    expect(controller.state.totalTimeSavedMinutes, 2);
    await controller.refresh();
    expect(controller.state.totalBlockedToday, 1);
    expect(controller.state.totalRecordedBlocks, 2);
    expect(controller.state.totalTimeSavedMinutes, 2);
  });

  test('dashboard and statistics sum the same recorded estimates', () async {
    final stats = await storage.getUsageStats();
    expect(controller.state.totalBlockedToday, stats.totalBlockedToday);
    expect(controller.state.totalTimeSavedMinutes, stats.totalTimeSavedMinutes);

    bridge.emitBlock();
    bridge.emitBlock();
    await pumpEventQueue();
    final updated = await storage.getUsageStats();
    expect(controller.state.totalBlockedToday, updated.totalBlockedToday);
    expect(
        controller.state.totalTimeSavedMinutes, updated.totalTimeSavedMinutes);
  });

  testWidgets('first use shows an empty state instead of inferred metrics',
      (tester) async {
    await storage.clearHistory();
    await controller.refresh();
    await tester.pumpWidget(MaterialApp(
      home: DashboardScreen(controller: controller),
    ));

    expect(find.byKey(const Key('dashboard_empty')), findsOneWidget);
    expect(find.byKey(const Key('card_blocked_today')), findsNothing);
    expect(find.byKey(const Key('card_time_saved')), findsNothing);
    expect(find.byKey(const Key('card_focus_streak')), findsNothing);

    await storage.addHistoryLog(HistoryLog(
      id: 'new',
      timestamp: DateTime.now(),
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      interventionMode: InterventionMode.immediateBack,
    ));
    await controller.refresh();
    await tester.pump();
    expect(find.byKey(const Key('dashboard_empty')), findsNothing);
    expect(find.text('Reels blocked\nToday'), findsOneWidget);
    expect(find.text('Estimated time saved\nAll time'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('card_focus_streak')), 200);
    expect(find.byKey(const Key('streak_title')), findsOneWidget);
  });

  test('toggleApp persists the rule and syncs the effective toggle', () async {
    await controller.toggleApp('com.instagram.android', true);

    expect(storage.rules['com.instagram.android']!.isEnabled, isTrue);
    expect(
      bridge.syncAppTogglesCalls.last['com.instagram.android'],
      isTrue,
    );
  });

  test('quick boost persists and syncs a real schedule', () async {
    await controller.activateQuickBoost('Deep Work', 25);

    final boost = storage.schedules.values
        .where((schedule) => schedule.id.startsWith('quick_boost'))
        .single;
    expect(bridge.syncSchedulesCalls, isNotEmpty);
    expect(boost.name, 'Deep Work');
    expect(
      boost.targetPackageNames,
      contains('com.google.android.youtube'),
    );
    expect(controller.state.activeBoostRemainingSeconds, 1500);
  });

  test('quick boost countdown ticks down and expires cleanly', () async {
    var now = DateTime(2026, 1, 1, 10);
    final timed = DashboardController(
      bridge,
      storage: storage,
      clock: () => now,
      boostTickInterval: const Duration(milliseconds: 10),
    );
    addTearDown(timed.dispose);

    await timed.refresh();
    await timed.activateQuickBoost('Pomodoro', 25);
    expect(timed.state.activeBoostRemainingSeconds, 1500);

    now = now.add(const Duration(minutes: 10));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(timed.state.activeBoostRemainingSeconds, 900);

    now = now.add(const Duration(minutes: 15));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await pumpEventQueue();

    expect(timed.state.activeBoostSessionName, isNull);
    expect(timed.state.activeBoostRemainingSeconds, isNull);
    expect(
      storage.schedules.keys.any((id) => id.startsWith('quick_boost')),
      isFalse,
    );
    expect(
      bridge.syncSchedulesCalls.last.any(
        (schedule) => schedule.id.startsWith('quick_boost'),
      ),
      isFalse,
    );
  });

  test('quick boost can be ended early and is removed from native sync',
      () async {
    await controller.activateQuickBoost('Deep Work', 60);

    await controller.endQuickBoost();
    await pumpEventQueue();

    expect(controller.state.activeBoostSessionName, isNull);
    expect(
      storage.schedules.keys.any((id) => id.startsWith('quick_boost')),
      isFalse,
    );
    expect(
      bridge.syncSchedulesCalls.last.any(
        (schedule) => schedule.id.startsWith('quick_boost'),
      ),
      isFalse,
    );
  });

  test('refresh restores a running quick boost countdown', () async {
    final start = DateTime(2026, 1, 1, 10);
    final now = start.add(const Duration(minutes: 10));
    await storage.saveSchedule(
      ScheduleModel(
        id: 'quick_boost_${start.millisecondsSinceEpoch}',
        name: 'Deep Work',
        daysOfWeek: [start.weekday],
        startHour: start.hour,
        startMinute: start.minute,
        endHour: 11,
        endMinute: 0,
        targetPackageNames: const ['com.google.android.youtube'],
      ),
    );

    final timed = DashboardController(
      bridge,
      storage: storage,
      clock: () => now,
      boostTickInterval: const Duration(milliseconds: 10),
    );
    addTearDown(timed.dispose);

    await timed.refresh();
    await pumpEventQueue();

    expect(timed.state.activeBoostSessionName, 'Deep Work');
    expect(timed.state.activeBoostRemainingSeconds, 3000);
  });

  test('expired one-shot boost is not revived the following week', () async {
    final start = DateTime(2026, 1, 1, 10);
    await storage.saveSchedule(
      ScheduleModel(
        id: 'quick_boost_${start.millisecondsSinceEpoch}',
        name: 'Pomodoro',
        daysOfWeek: [start.weekday],
        startHour: start.hour,
        startMinute: start.minute,
        endHour: 10,
        endMinute: 25,
        targetPackageNames: const ['com.google.android.youtube'],
      ),
    );

    final now = start.add(const Duration(days: 7, minutes: 5));
    final timed = DashboardController(
      bridge,
      storage: storage,
      clock: () => now,
      boostTickInterval: const Duration(milliseconds: 10),
    );
    addTearDown(timed.dispose);

    await timed.refresh();
    await pumpEventQueue();

    expect(timed.state.activeBoostSessionName, isNull);
    expect(
      storage.schedules.keys.any((id) => id.startsWith('quick_boost')),
      isFalse,
    );
  });
}
