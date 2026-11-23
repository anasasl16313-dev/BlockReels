import 'dart:io';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/platform_channel/mock_platform_bridge.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/schedules_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorageRepository storage;
  late MockPlatformBridge bridge;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('schedules_notifier_test_');
    storage = HiveStorageRepository();
    await storage.init(customPath: tempDir.path);
    bridge = MockPlatformBridge();

    container = ProviderContainer(
      overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    bridge.dispose();
    await storage.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SchedulesNotifier State Management Tests', () {
    test('addSchedule persists to storage and syncs to platform bridge',
        () async {
      final notifier = container.read(schedulesProvider.notifier);
      await notifier.loadSchedules();

      final schedule = ScheduleModel(
        id: 'sch_morning',
        name: 'Morning Focus',
        daysOfWeek: [1, 2, 3, 4, 5],
        startHour: 8,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await notifier.addSchedule(schedule);

      final state = container.read(schedulesProvider);
      expect(state.length, 1);
      expect(state.first.name, 'Morning Focus');

      final stored = await storage.getSchedules();
      expect(stored.length, 1);
      expect(stored.first.id, 'sch_morning');

      expect(bridge.syncSchedulesCalls.isNotEmpty, isTrue);
      expect(bridge.syncSchedulesCalls.last.first.title, 'Morning Focus');
    });

    test('toggleSchedule updates active status in storage and bridge',
        () async {
      final notifier = container.read(schedulesProvider.notifier);
      await notifier.loadSchedules();

      final schedule = ScheduleModel(
        id: 'sch_1',
        name: 'Evening Chill',
        daysOfWeek: [1, 2, 3],
        startHour: 18,
        startMinute: 0,
        endHour: 20,
        endMinute: 0,
      );
      await notifier.addSchedule(schedule);

      await notifier.toggleSchedule('sch_1', false);

      final state = container.read(schedulesProvider);
      expect(state.first.isActive, isFalse);

      final stored = await storage.getSchedule('sch_1');
      expect(stored!.isActive, isFalse);
    });

    test('deleteSchedule removes schedule from state and storage', () async {
      final notifier = container.read(schedulesProvider.notifier);
      await notifier.loadSchedules();

      final schedule = ScheduleModel(
        id: 'sch_to_delete',
        name: 'Temporary Schedule',
        daysOfWeek: [1],
        startHour: 10,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );
      await notifier.addSchedule(schedule);

      await notifier.deleteSchedule('sch_to_delete');

      final state = container.read(schedulesProvider);
      expect(state, isEmpty);

      final stored = await storage.getSchedules();
      expect(stored, isEmpty);
    });
  });
}
