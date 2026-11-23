import 'dart:async';

import 'package:block_reels/core/models/quick_boost_window.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/platform_channel/dtos/schedule_dto.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/features/dashboard/dashboard.dart';
import 'package:block_reels/features/dashboard/presentation/controllers/dashboard_providers.dart';
import 'package:block_reels/features/schedules/schedules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

class PausingScheduleBridge extends FakePlatformBridge {
  Completer<void>? pauseNextSync;
  Completer<void>? syncStarted;
  bool reject = false;

  @override
  Future<bool> syncSchedules(List<ScheduleDto> schedules) async {
    final pause = pauseNextSync;
    pauseNextSync = null;
    await super.syncSchedules(schedules);
    if (pause != null) {
      syncStarted!.complete();
      await pause.future;
    }
    return !reject;
  }
}

void main() {
  const regular = ScheduleRuleModel(
    id: 'work',
    name: 'Work',
    daysOfWeek: [1, 3, 5],
    startHour: 9,
    startMinute: 0,
    endHour: 17,
    endMinute: 0,
    enabledPackageNames: ['com.instagram.android'],
  );

  late FakeStorageRepository storage;
  late PausingScheduleBridge bridge;
  late ProviderContainer container;
  late SchedulesController schedules;
  late DashboardController dashboard;

  setUp(() async {
    storage = FakeStorageRepository();
    await storage.saveSchedule(regular.toCoreModel());
    bridge = PausingScheduleBridge();
    container = ProviderContainer(overrides: [
      storageRepositoryProvider.overrideWithValue(storage),
      platformBridgeProvider.overrideWithValue(bridge),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await bridge.dispose();
  });

  Future<void> initialize() async {
    dashboard = container.read(dashboardControllerProvider);
    schedules = container.read(schedulesControllerProvider);
    await dashboard.refresh();
    await pumpEventQueue();
  }

  test('editing a regular schedule retains the running boost in native sync',
      () async {
    await initialize();
    await dashboard.activateQuickBoost('Focus', 25);
    final boostId = storage.schedules.keys.singleWhere(isQuickBoostId);

    expect(await schedules.updateSchedule(regular.copyWith(name: 'Deep Work')),
        ScheduleWriteResult.success);

    expect(bridge.syncSchedulesCalls.last.map((s) => s.id),
        unorderedEquals(['work', boostId]));
    expect(storage.schedules.keys, unorderedEquals(['work', boostId]));
    expect(schedules.schedules.map((s) => s.id), ['work']);
    expect(schedules.allSchedules.map((s) => s.id), contains(boostId));
    expect(dashboard.state.activeBoostSessionName, 'Focus');
    expect(dashboard.state.activeBoostRemainingSeconds, greaterThan(0));
    expect(container.read(dashboardControllerProvider), same(dashboard));
  });

  test('editing a previously loaded schedule cannot resend an ended boost',
      () async {
    final now = DateTime.now();
    final end = now.add(const Duration(minutes: 25));
    final boost = ScheduleModel(
      id: '$quickBoostIdPrefix${now.millisecondsSinceEpoch}',
      name: 'Focus',
      daysOfWeek: [now.weekday],
      startHour: now.hour,
      startMinute: now.minute,
      endHour: end.hour,
      endMinute: end.minute,
    );
    await storage.saveSchedule(boost);
    await initialize();
    final previouslyLoaded = schedules.schedules.single;
    expect(schedules.allSchedules.map((s) => s.id), contains(boost.id));

    await dashboard.endQuickBoost();
    expect(
        await schedules.updateSchedule(
            previouslyLoaded.copyWith(name: 'Edited after ending')),
        ScheduleWriteResult.success);

    expect(bridge.syncSchedulesCalls.last.map((s) => s.id), ['work']);
    expect(storage.schedules.keys, ['work']);
    expect(schedules.allSchedules.map((s) => s.id), ['work']);
    expect(dashboard.state.activeBoostSessionName, isNull);
  });

  test('queued regular edits survive boost start, replacement and end',
      () async {
    await initialize();
    final release = Completer<void>();
    bridge.pauseNextSync = release;
    bridge.syncStarted = Completer<void>();
    final start = dashboard.activateQuickBoost('Focus', 25);
    await bridge.syncStarted!.future;
    final callsBeforeEdit = bridge.syncSchedulesCalls.length;

    final edit = schedules.updateSchedule(regular.copyWith(name: 'Latest'));
    await pumpEventQueue();
    expect(bridge.syncSchedulesCalls.length, callsBeforeEdit);
    expect(schedules.isBusy, isTrue);
    release.complete();
    await start;
    expect(await edit, ScheduleWriteResult.success);

    await dashboard.activateQuickBoost('Longer focus', 60);
    expect(schedules.schedules.single.name, 'Latest');
    expect(bridge.syncSchedulesCalls.last.map((s) => s.title),
        unorderedEquals(['Latest', 'Longer focus']));
    await dashboard.endQuickBoost();
    expect(schedules.isBusy, isFalse);
    expect(storage.schedules['work']!.name, 'Latest');
    expect(storage.schedules['work']!.targetPackageNames,
        regular.enabledPackageNames);
    expect(bridge.syncSchedulesCalls.last.single.title, 'Latest');
  });

  test('failed boost rolls back before the next regular mutation', () async {
    await initialize();
    bridge.reject = true;
    final start = dashboard.activateQuickBoost('Focus', 25);
    final edit =
        schedules.updateSchedule(regular.copyWith(name: 'Saved locally'));
    await start;
    expect(await edit, ScheduleWriteResult.syncFailed);
    expect(dashboard.state.activeBoostSessionName, isNull);
    expect(dashboard.boostUncertain, isTrue);
    expect(dashboard.boostError, contains('Could not start'));
    expect(storage.schedules.keys, ['work']);
    expect(schedules.allSchedules.single.name, 'Saved locally');

    bridge.reject = false;
    await dashboard.retryProtectionStatus();
    expect(dashboard.boostUncertain, isFalse);
    expect(schedules.hasUnsyncedChanges, isFalse);
    expect(bridge.syncSchedulesCalls.last.single.title, 'Saved locally');
  });

  testWidgets('boost expiration preserves regular schedules', (tester) async {
    var now = DateTime(2026, 10, 30, 10);
    schedules = container.read(schedulesControllerProvider);
    final timed = DashboardController(
      bridge,
      storage: storage,
      schedulesController: schedules,
      clock: () => now,
      boostTickInterval: const Duration(seconds: 1),
    );
    addTearDown(timed.dispose);
    await timed.refresh();
    await timed.activateQuickBoost('Focus', 1);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(timed.state.activeBoostSessionName, isNull);
    expect(storage.schedules.keys, ['work']);
    expect(schedules.schedules.single, regular);
    expect(bridge.syncSchedulesCalls.last.single.id, 'work');
  });
}
