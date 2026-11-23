import 'dart:async';
import 'dart:io';

import 'package:block_reels/app.dart';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/platform_channel/dtos/platform_event.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/services/block_event_recorder.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../test_helpers/fake_services.dart';

class AcknowledgementBridge extends FakePlatformBridge {
  bool acceptAcknowledgements = true;
  Completer<void>? firstReadGate;
  final firstReadStarted = Completer<void>();
  final readLimits = <int>[];

  @override
  Future<List<BlockEvent>> readPendingBlockEvents({int limit = 100}) async {
    readLimits.add(limit);
    final snapshot = await super.readPendingBlockEvents(limit: limit);
    final gate = firstReadGate;
    firstReadGate = null;
    if (gate != null) {
      firstReadStarted.complete();
      await gate.future;
    }
    return snapshot;
  }

  @override
  Future<bool> acknowledgeBlockEvents(List<String> ids) async {
    if (!acceptAcknowledgements) {
      acknowledgedBlockEventCalls.add(List<String>.from(ids));
      return false;
    }
    return super.acknowledgeBlockEvents(ids);
  }
}

class HistorySaveFault {
  final Set<String> failingIds = {};
}

/// Real Hive storage with only the selected history put rejected.
class HistoryFaultBox<T> implements Box<T> {
  final Box<T> box;
  final HistorySaveFault fault;
  HistoryFaultBox(this.box, this.fault);

  @override
  Future<void> put(dynamic key, T value) async {
    if (fault.failingIds.contains(key)) {
      throw const FileSystemException('Injected history save failure');
    }
    await box.put(key, value);
  }

  @override
  Future<int> clear() => box.clear();
  @override
  bool containsKey(dynamic key) => box.containsKey(key);
  @override
  bool get isEmpty => box.isEmpty;
  @override
  Iterable<T> get values => box.values;
  @override
  Map<dynamic, T> toMap() => box.toMap();
  @override
  Future<void> flush() => box.flush();
  @override
  Future<void> close() => box.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('durable block delivery with real Hive storage', () {
    late Directory directory;
    late HiveStorageRepository storage;
    late HistorySaveFault fault;
    late AcknowledgementBridge bridge;
    BlockEventRecorder? recorder;
    StreamSubscription<HistoryLog>? updates;
    late List<HistoryLog> recorded;

    Future<HiveStorageRepository> openStorage() async {
      Future<Box<T>> open<T>(String name) async {
        final box = await Hive.openBox<T>(name, crashRecovery: false);
        return name == HiveStorageRepository.boxHistoryName
            ? HistoryFaultBox(box, fault)
            : box;
      }

      final repository = HiveStorageRepository(openBox: open);
      await repository.init(customPath: directory.path);
      return repository;
    }

    Future<void> connect() async {
      recorded = [];
      recorder = BlockEventRecorder(bridge, storage);
      updates = recorder!.recordedLogs.listen(recorded.add);
      recorder!.start();
      await recorder!.drainPending();
      await pumpEventQueue();
    }

    Future<void> disconnect() async {
      await recorder?.dispose();
      recorder = null;
      await updates?.cancel();
      updates = null;
    }

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('block_delivery_test_');
      fault = HistorySaveFault();
      bridge = AcknowledgementBridge();
      storage = await openStorage();
    });

    tearDown(() async {
      await disconnect();
      await storage.close();
      await Hive.close();
      await bridge.dispose();
      await directory.delete(recursive: true);
    });

    test('clearing history drops late notifications and accepts later blocks', () async {
      await connect();
      bridge.acceptAcknowledgements = false;
      final old = BlockEvent.fromJson({
        'eventId': 'old',
        'durablyQueued': true,
        'packageName': 'example.app',
      });
      bridge.pendingBlockEvents['old'] = old;
      await recorder!.drainPending();
      expect(await storage.getHistoryLogs(), hasLength(1));
      await recorder!.clearHistory();
      bridge.emitPlatformEvent(old);
      await pumpEventQueue();
      expect(await storage.getHistoryLogs(), isEmpty);
      bridge.acceptAcknowledgements = true;
      bridge.emitBlock(eventId: 'after-clear');
      await recorder!.drainPending();
      expect((await storage.getHistoryLogs()).single.id, 'after-clear');
    });

    test('new pending events persist codes instead of captions or accessibility text', () async {
      final inputs = [
        'A private caption from the screen',
        'PRIVATE_CAPTION',
        'com.instagram.android:id/private_caption',
        'CONTENT_DESCRIPTION',
        'CLIPS_CONTAINER',
      ];
      for (var i = 0; i < inputs.length; i++) {
        bridge.pendingBlockEvents['privacy-$i'] = BlockEvent.fromJson({
          'eventType': 'REEL_BLOCKED',
          'eventId': 'privacy-$i',
          'timestamp': 12345 + i,
          'packageName': 'com.instagram.android',
          'appType': 'INSTAGRAM',
          'interventionMode': 'AUTO_BACK',
          'detectionReason': inputs[i],
          'matchedText': 'Unstored accessibility text',
        });
      }
      await connect();
      expect(recorded.map((log) => log.detectionReason), [
        'SURGICAL_HEURISTIC',
        'SURGICAL_HEURISTIC',
        'SURGICAL_HEURISTIC',
        'CONTENT_DESCRIPTION',
        'CLIPS_CONTAINER',
      ]);
      expect(bridge.pendingBlockEvents, isEmpty);
      await disconnect();
      await storage.close();
      await Hive.close();
      storage = await openStorage();
      final saved = await storage.getHistoryLogs();
      expect(saved, hasLength(5));
      final serialized = saved.map((log) => log.toJson()).toString();
      for (final raw in inputs.take(3)) {
        expect(serialized, isNot(contains(raw)));
      }
      expect(serialized, isNot(contains('Unstored accessibility text')));
      expect(
        saved.firstWhere((log) => log.id == 'privacy-3').detectionReason,
        'CONTENT_DESCRIPTION',
      );
      expect(
        saved.firstWhere((log) => log.id == 'privacy-4').detectionReason,
        'CLIPS_CONTAINER',
      );
    });

    test('new direct history writes sanitize reasons while old Hive and JSON history stay readable', () async {
      const raw = 'Legacy caption and accessibility description';
      final legacy = HistoryLog.fromJson({
        'id': 'legacy-history',
        'timestamp': 12345,
        'packageName': 'com.instagram.android',
        'appName': 'Instagram',
        'interventionMode': 'immediateBack',
        'detectionReason': raw,
      });
      // Simulate bytes written by an older version, outside the new-write boundary.
      await Hive.box<HistoryLog>(HiveStorageRepository.boxHistoryName)
          .put(legacy.id, legacy);
      expect(HistoryLog.fromJson(legacy.toJson()).detectionReason, raw);
      await storage.addHistoryLog(legacy.copyWith(id: 'new-direct'));
      expect(
        await storage.addHistoryLogIfAbsent(
          legacy.copyWith(id: 'new-idempotent'),
        ),
        isTrue,
      );
      await storage.close();
      await Hive.close();
      storage = await openStorage();
      final logs = await storage.getHistoryLogs();
      expect(
        logs.firstWhere((log) => log.id == legacy.id).detectionReason,
        raw,
      );
      expect(
        logs
            .where((log) => log.id.startsWith('new-'))
            .map((log) => log.detectionReason),
        everyElement('SURGICAL_HEURISTIC'),
      );
      expect(logs, hasLength(3));
    });

    test(
      'detached events drain on connection and again after reconnect',
      () async {
        bridge.emitBlock(eventId: 'detached-1');
        bridge.emitBlock(eventId: 'detached-2');
        await connect();
        expect(recorded.map((log) => log.id), ['detached-1', 'detached-2']);
        expect(bridge.pendingBlockEvents, isEmpty);
        await disconnect();
        bridge.emitBlock(eventId: 'detached-3');
        await connect();
        expect(recorded.map((log) => log.id), ['detached-3']);
        expect(
          (await storage.getHistoryLogs()).map((log) => log.id),
          unorderedEquals(['detached-1', 'detached-2', 'detached-3']),
        );
        expect(bridge.pendingBlockEvents, isEmpty);
      },
    );

    test(
      'live and pending duplicates insert and update the UI only once',
      () async {
        await connect();
        bridge.emitBlock(eventId: 'duplicate');
        await recorder!.drainPending();
        await pumpEventQueue();
        bridge.emitBlock(eventId: 'duplicate');
        await recorder!.drainPending();
        await pumpEventQueue();
        expect((await storage.getHistoryLogs()).single.id, 'duplicate');
        expect(recorded.map((log) => log.id), ['duplicate']);
        expect(bridge.pendingBlockEvents, isEmpty);
      },
    );

    test(
      'failed Hive save is not acknowledged while successful records are',
      () async {
        fault.failingIds.add('failed');
        bridge.emitBlock(eventId: 'failed');
        bridge.emitBlock(eventId: 'saved');
        await connect();
        expect((await storage.getHistoryLogs()).map((log) => log.id), [
          'saved',
        ]);
        expect(recorded.map((log) => log.id), ['saved']);
        expect(bridge.acknowledgedBlockEventCalls.expand((ids) => ids), [
          'saved',
        ]);
        expect(bridge.pendingBlockEvents.keys, ['failed']);
        fault.failingIds.clear();
        await recorder!.drainPending();
        await pumpEventQueue();
        expect(recorded.map((log) => log.id), ['saved', 'failed']);
        expect(bridge.pendingBlockEvents, isEmpty);
        expect((await storage.getHistoryLogs()).length, 2);
      },
    );

    test('restart between Hive save and acknowledgement does not duplicate history', () async {
      bridge.acceptAcknowledgements = false;
      bridge.emitBlock(eventId: 'saved-before-restart');
      await connect();
      expect(recorded, hasLength(1));
      expect(bridge.pendingBlockEvents, hasLength(1));
      await disconnect();
      await storage.close();
      await Hive.close();

      storage = await openStorage();
      bridge.acceptAcknowledgements = true;
      await connect();
      expect(
        (await storage.getHistoryLogs()).single.id,
        'saved-before-restart',
      );
      expect(recorded, isEmpty);
      expect(bridge.pendingBlockEvents, isEmpty);
    });

    test(
      'connection notification closes the initial read and subscribe gap',
      () async {
        final release = Completer<void>();
        bridge.firstReadGate = release;
        recorded = [];
        recorder = BlockEventRecorder(bridge, storage);
        updates = recorder!.recordedLogs.listen(recorded.add);
        recorder!.start();
        await bridge.firstReadStarted.future;
        bridge.pendingBlockEvents['in-gap'] = const BlockEvent(
          eventId: 'in-gap',
          timestamp: 12345,
          packageName: 'com.instagram.android',
          appType: 'INSTAGRAM',
          interventionMode: 'AUTO_BACK',
        );
        bridge.emitPlatformEvent(
          const GenericPlatformEvent(
            eventType: 'BLOCK_EVENTS_CONNECTED',
            timestamp: 12346,
            payload: {},
          ),
        );
        await pumpEventQueue();
        release.complete();
        await recorder!.drainPending();
        await pumpEventQueue();
        expect((await storage.getHistoryLogs()).single.id, 'in-gap');
        expect(recorded.map((log) => log.id), ['in-gap']);
        expect(bridge.pendingBlockEvents, isEmpty);
      },
    );

    test(
      'drains multiple bounded batches without synthesizing old counters',
      () async {
        bridge.emitBlock(); // Older detached event: no stable ID or native pending row.
        for (var i = 0; i < 205; i++) {
          bridge.emitBlock(eventId: 'pending-$i');
        }
        await connect();
        expect((await storage.getHistoryLogs(limit: 300)).length, 205);
        expect(recorded.length, 205);
        expect(bridge.readLimits, everyElement(100));
        expect(bridge.acknowledgedBlockEventCalls.map((ids) => ids.length), [
          100,
          100,
          5,
        ]);
        expect(bridge.pendingBlockEvents, isEmpty);
      },
    );

    test('older live events without IDs still decode and save without acknowledgement', () async {
      await connect();
      final old = BlockEvent.fromJson({
        'timestamp': 12345,
        'app': 'com.instagram.android',
        'appType': 'INSTAGRAM',
        'action': 'AUTO_BACK',
      });
      expect(old.eventId, isNull);
      bridge.emitPlatformEvent(old);
      await pumpEventQueue();
      // Dispose waits for any actual Hive I/O queued by the live event.
      await disconnect();
      expect((await storage.getHistoryLogs()).single.id, isNotEmpty);
      expect(recorded, hasLength(1));
      expect(bridge.acknowledgedBlockEventCalls, isEmpty);
    });
  });

  testWidgets('app resume drains pending events without a live notification', (
    tester,
  ) async {
    final storage = FakeStorageRepository();
    final bridge = FakePlatformBridge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageRepositoryProvider.overrideWithValue(storage),
          platformBridgeProvider.overrideWithValue(bridge),
        ],
        child: const BlockReelsApp(),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    bridge.pendingBlockEvents['resume'] = const BlockEvent(
      eventId: 'resume',
      timestamp: 12345,
      packageName: 'com.instagram.android',
      appType: 'INSTAGRAM',
      interventionMode: 'AUTO_BACK',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(storage.history.single.id, 'resume');
    expect(bridge.pendingBlockEvents, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await bridge.dispose();
  });
}
