import 'dart:io';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/providers/history_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorageRepository storage;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_notifier_test_');
    storage = HiveStorageRepository();
    await storage.init(customPath: tempDir.path);

    container = ProviderContainer(
      overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await storage.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HistoryNotifier State Management Tests', () {
    test('addLog prepends log to state and saves to storage', () async {
      final notifier = container.read(historyProvider.notifier);

      final log = HistoryLog(
        id: 'hist_1',
        timestamp: DateTime.now(),
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        interventionMode: InterventionMode.mindfulPause,
      );

      await notifier.addLog(log);

      final state = container.read(historyProvider);
      expect(state.length, 1);
      expect(state.first.id, 'hist_1');

      final stored = await storage.getHistoryLogs();
      expect(stored.length, 1);
      expect(stored.first.packageName, 'com.instagram.android');
    });

    test('clearHistory empties state and storage', () async {
      final notifier = container.read(historyProvider.notifier);

      await notifier.addLog(
        HistoryLog(
          id: 'log_a',
          timestamp: DateTime.now(),
          packageName: 'com.zhiliaoapp.musically',
          appName: 'TikTok',
          interventionMode: InterventionMode.mindfulPause,
        ),
      );

      await notifier.clearHistory();

      final state = container.read(historyProvider);
      expect(state, isEmpty);

      final stored = await storage.getHistoryLogs();
      expect(stored, isEmpty);
    });
  });
}
