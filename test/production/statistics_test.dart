import 'dart:async';

import 'package:block_reels/core/services/block_event_recorder.dart';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/features/statistics/statistics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

class _PausedReadStorage extends FakeStorageRepository {
  Completer<void>? readGate;
  int reads = 0;

  @override
  Future<List<HistoryLog>> getHistoryLogs(
      {int limit = 100, DateTime? since}) async {
    reads++;
    final snapshot = await super.getHistoryLogs(limit: limit, since: since);
    await readGate?.future;
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageRepository storage;
  late FakePlatformBridge bridge;
  late BlockEventRecorder recorder;
  late StatisticsController controller;

  setUp(() async {
    storage = FakeStorageRepository();
    bridge = FakePlatformBridge();
    recorder = BlockEventRecorder(bridge, storage)..start();
    controller = StatisticsController(storage, recorder);
    await controller.loadFromStorage();
  });

  tearDown(() async {
    controller.dispose();
    await recorder.dispose();
    await bridge.dispose();
  });

  test('recorded events update summary and persist history', () async {
    bridge.emitBlock(
      packageName: 'com.instagram.android',
      appType: 'INSTAGRAM',
    );
    bridge.emitBlock(
      packageName: 'com.zhiliaoapp.musically',
      appType: 'TIKTOK',
    );
    await pumpEventQueue();

    expect(storage.history, hasLength(2));
    expect(controller.records, hasLength(2));
    expect(controller.summary.totalBlocks, 2);
    expect(controller.summary.blocksByApp['Instagram'], 1);
    expect(controller.summary.blocksByApp['TikTok'], 1);
  });

  test('clearHistory clears both controller records and storage', () async {
    bridge.emitBlock();
    await pumpEventQueue();

    await controller.clearHistory();
    expect(controller.records, isEmpty);
    expect(storage.history, isEmpty);
  });

  test('all-time reads records beyond the repository default page', () async {
    final at = DateTime.now();
    for (var i = 0; i < 105; i++) {
      await storage.addHistoryLog(
        HistoryLog(
          id: 'stored_$i',
          timestamp: at,
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          interventionMode: InterventionMode.immediateBack,
        ),
      );
    }
    await controller.loadFromStorage();
    controller.setTimeframe(StatsTimeframe.allTime);

    expect(controller.records, hasLength(105));
    expect(controller.summary.totalBlocks, 105);
    expect(controller.summary.totalTimeSavedMinutes, 78);
  });
  test(
    'timeframe cache expires on date changes without deleting records',
    () async {
      final day = DateTime(2026, 11, 2, 23, 59);
      controller.setMockNow(day);
      await controller.ingestRecord(
        BlockRecord(
          id: 'midnight',
          packageName: 'com.instagram.android',
          appType: 'INSTAGRAM',
          timestamp: day,
        ),
      );
      final today = controller.summary;
      expect(today.totalBlocks, 1);
      expect(identical(controller.summary, today), isTrue);
      controller.setTimeframe(StatsTimeframe.allTime);
      final all = controller.summary;
      controller.setTimeframe(StatsTimeframe.today);
      expect(identical(controller.summary, today), isTrue);
      controller.setMockNow(DateTime(2026, 11, 3));
      expect(controller.summary.totalBlocks, 0);
      controller.setTimeframe(StatsTimeframe.allTime);
      expect(controller.summary.totalBlocks, 1);
      expect(identical(controller.summary, all), isFalse);
      expect(controller.records, hasLength(1));
    },
  );
  test('shared delayed refresh cannot replay an append after clear', () async {
    final delayed = _PausedReadStorage();
    final stats = StatisticsController(delayed);
    addTearDown(stats.dispose);
    await stats.loadFromStorage();
    expect(delayed.reads, 1, reason: 'initial refresh callers share one read');
    delayed.readGate = Completer<void>();
    final refresh = stats.loadFromStorage();
    final sharedRefresh = stats.loadFromStorage();
    await pumpEventQueue();
    expect(delayed.reads, 2);
    await delayed.addHistoryLog(HistoryLog(
      id: 'old_append',
      timestamp: DateTime.now(),
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      interventionMode: InterventionMode.immediateBack,
    ));
    await delayed.clearHistory();
    await pumpEventQueue();
    delayed.readGate!.complete();
    delayed.readGate = null;
    await Future.wait([refresh, sharedRefresh]);
    await pumpEventQueue();
    expect(stats.records, isEmpty);
    expect(stats.summary.totalBlocks, 0);
  });
}
