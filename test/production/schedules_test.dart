import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/features/schedules/schedules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleModel interval semantics', () {
    test('editing preserves a stored mode override', () {
      final stored = ScheduleModel(
          id: 'old',
          name: 'Old',
          daysOfWeek: const [1],
          startHour: 9,
          startMinute: 0,
          endHour: 10,
          endMinute: 0,
          overrideMode: InterventionMode.strictBlock);
      final edited = ScheduleRuleModel.fromCoreModel(stored)
          .copyWith(name: 'Updated')
          .toCoreModel();
      expect(edited.overrideMode, InterventionMode.strictBlock);
      final feature = ScheduleRuleModel.fromCoreModel(edited);
      expect(ScheduleRuleModel.fromMap(feature.toMap()).overrideMode,
          InterventionMode.strictBlock);
    });
    ScheduleModel schedule({
      required int startHour,
      required int startMinute,
      required int endHour,
      required int endMinute,
      List<int> days = const [1, 2, 3, 4, 5],
    }) {
      return ScheduleModel(
        id: 's',
        name: 'Focus',
        daysOfWeek: days,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
      );
    }

    test('same-day interval is end-exclusive', () {
      final model = schedule(
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
      );
      expect(model.isCurrentlyActive(DateTime(2026, 8, 17, 8, 59)), isFalse);
      expect(model.isCurrentlyActive(DateTime(2026, 8, 17, 9, 0)), isTrue);
      expect(model.isCurrentlyActive(DateTime(2026, 8, 17, 16, 59)), isTrue);
      expect(model.isCurrentlyActive(DateTime(2026, 8, 17, 17, 0)), isFalse);
    });

    test('midnight-crossing interval checks the previous ISO weekday', () {
      final model = schedule(
        startHour: 22,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
        days: const [1],
      );
      expect(model.isCurrentlyActive(DateTime(2026, 8, 17, 23, 0)), isTrue);
      expect(model.isCurrentlyActive(DateTime(2026, 8, 18, 5, 59)), isTrue);
      expect(model.isCurrentlyActive(DateTime(2026, 8, 18, 6, 0)), isFalse);
      expect(model.isCurrentlyActive(DateTime(2026, 8, 19, 2, 0)), isFalse);
    });

    test('zero-duration interval is never active', () {
      final model = schedule(
        startHour: 10,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );
      expect(model.isCurrentlyActive(DateTime(2026, 8, 17, 10, 0)), isFalse);
    });
  });

  test('evaluator treats a quick boost as a one-shot epoch window', () {
    final startedAt = DateTime(2026, 8, 19, 10, 0); // Wednesday
    final boost = ScheduleModel(
      id: 'quick_boost_${startedAt.millisecondsSinceEpoch}',
      name: 'Quick Boost',
      daysOfWeek: const [1],
      startHour: 10,
      startMinute: 0,
      endHour: 10,
      endMinute: 25,
    );

    expect(
      ScheduleEvaluator.isScheduleActiveNow(
        boost,
        startedAt.add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
    expect(
      ScheduleEvaluator.isScheduleActiveNow(
        boost,
        startedAt.add(const Duration(days: 7)),
      ),
      isFalse,
    );
  });
  group('SchedulesController persistence', () {
    late FakeStorageRepository storage;
    late FakePlatformBridge bridge;
    late SchedulesController controller;

    setUp(() async {
      storage = FakeStorageRepository();
      bridge = FakePlatformBridge();
      controller = SchedulesController(bridge, storage);
      await pumpEventQueue();
    });

    tearDown(() async {
      controller.dispose();
      await bridge.dispose();
    });

    test('add, update, toggle, and delete stay in sync with storage', () async {
      const model = ScheduleRuleModel(
        id: 'work',
        name: 'Work',
        daysOfWeek: [1, 2, 3, 4, 5],
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        enabledPackageNames: ['com.instagram.android'],
      );
      await controller.addSchedule(model);
      await pumpEventQueue();

      expect(storage.schedules['work'], isNotNull);
      expect(bridge.syncSchedulesCalls.last.single.title, 'Work');

      await controller.toggleSchedule('work', false);
      await pumpEventQueue();
      expect(storage.schedules['work']!.isActive, isFalse);

      await controller.updateSchedule(model.copyWith(name: 'Deep Work'));
      await pumpEventQueue();
      expect(storage.schedules['work']!.name, 'Deep Work');

      await controller.deleteSchedule('work');
      await pumpEventQueue();
      expect(storage.schedules, isEmpty);
    });

    test('quick boost stays out of the visible list but syncs to native',
        () async {
      final startedAt = DateTime(2026, 8, 19, 10, 0);
      final quickBoostId = 'quick_boost_${startedAt.millisecondsSinceEpoch}';
      final quickBoost = ScheduleRuleModel(
        id: quickBoostId,
        name: 'Quick Boost',
        daysOfWeek: const [1],
        startHour: 10,
        startMinute: 0,
        endHour: 10,
        endMinute: 25,
        enabledPackageNames: const ['com.instagram.android'],
      );
      const normal = ScheduleRuleModel(
        id: 'work',
        name: 'Work',
        daysOfWeek: [1, 2, 3, 4, 5],
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        enabledPackageNames: ['com.instagram.android'],
      );

      await controller.addSchedule(quickBoost);
      await controller.addSchedule(normal);
      await pumpEventQueue();

      expect(
          controller.schedules.map((s) => s.id), isNot(contains(quickBoostId)));
      expect(controller.schedules.map((s) => s.id), contains('work'));
      final synced = bridge.syncSchedulesCalls.last;
      expect(synced.map((s) => s.id), contains(quickBoostId));
    });
  });
}
