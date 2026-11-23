import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/features/statistics/statistics.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/models/whitelist_item.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorageRepository repository;
  late DateTime now;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_repo_test_');
    now = DateTime.now();
    repository = HiveStorageRepository(clock: () => now);
    await repository.init(customPath: tempDir.path);
  });

  tearDown(() async {
    await repository.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HiveStorageRepository Implementation Tests', () {
    test('complete history stats cache writes and calendar rollover', () async {
      now = DateTime(2026, 11, 2, 23, 59);
      for (var i = 0; i < 150; i++) {
        await repository.addHistoryLog(
          HistoryLog(
            id: 'maintenance_$i',
            timestamp: DateTime(2026, 11, 2 - i % 3, 12),
            packageName: 'com.instagram.android',
            appName: 'Instagram',
            interventionMode: InterventionMode.immediateBack,
          ),
        );
      }
      final first = await repository.getUsageStats();
      expect(first.totalBlockedLifetime, 150);
      expect(first.totalBlockedToday, 50);
      expect(first.currentStreakDays, 3);
      expect(first.bestStreakDays, 3);
      expect(identical(await repository.getUsageStats(), first), isTrue);
      expect(await repository.calculateBestStreak(), 3);
      expect(await repository.calculateCurrentStreak(), 3);
      // The default recent page must never become a retention limit.
      expect(await repository.getHistoryLogs(), hasLength(100));
      expect(await repository.getHistoryLogs(limit: 1000), hasLength(150));

      now = DateTime(2026, 11, 3);
      final nextDay = await repository.getUsageStats();
      expect(identical(nextDay, first), isFalse);
      expect(nextDay.totalBlockedToday, 0);
      expect(nextDay.currentStreakDays, 3);
      now = DateTime(2026, 11, 5);
      expect((await repository.getUsageStats()).currentStreakDays, 0);
      expect((await repository.getUsageStats()).bestStreakDays, 3);

      await repository.addHistoryLog(
        HistoryLog(
          id: 'after_rollover',
          timestamp: now,
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          interventionMode: InterventionMode.immediateBack,
        ),
      );
      expect((await repository.getUsageStats()).totalBlockedLifetime, 151);
      expect((await repository.getUsageStats()).totalBlockedToday, 1);
      await repository.clearHistory();
      expect((await repository.getUsageStats()).totalBlockedLifetime, 0);
    });

    test(
      'summary caches follow external saves, history import and reset',
      () async {
        final controller = StatisticsController(repository);
        addTearDown(controller.dispose);
        await controller.loadFromStorage();
        controller.setTimeframe(StatsTimeframe.allTime);
        final empty = controller.summary;
        expect(identical(controller.summary, empty), isTrue);
        final log = HistoryLog(
          id: 'external',
          timestamp: now,
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          interventionMode: InterventionMode.immediateBack,
        );
        await repository.addHistoryLogIfAbsent(log);
        await pumpEventQueue();
        final saved = controller.summary;
        expect(saved.totalBlocks, 1);
        expect(identical(saved, empty), isFalse);
        controller.setTimeframe(StatsTimeframe.thisWeek);
        expect(controller.summary.totalBlocks, 1);
        controller.setTimeframe(StatsTimeframe.allTime);
        expect(identical(controller.summary, saved), isTrue);
        await repository.addHistoryLog(
          log.copyWith(estimatedTimeSavedSeconds: 90),
        );
        await pumpEventQueue();
        expect(controller.summary.totalTimeSavedSeconds, 90);
        expect(controller.summary.totalBlocks, 1);
        final beforeImport = await repository.getUsageStats();
        final data = {
          'history': [log.copyWith(id: 'imported').toJson()],
        };
        expect(
          await repository.importBackup(
            jsonEncode({
              'version': 1,
              'data': data,
              'checksum':
                  sha256.convert(utf8.encode(jsonEncode(data))).toString(),
            }),
          ),
          isTrue,
        );
        await pumpEventQueue();
        expect(controller.records.single.id, 'imported');
        expect(controller.summary.totalTimeSavedSeconds, 45);
        expect(
          identical(await repository.getUsageStats(), beforeImport),
          isFalse,
        );
        await repository.clearHistory();
        await pumpEventQueue();
        expect(controller.summary.totalBlocks, 0);
        await repository.addHistoryLog(log);
        await pumpEventQueue();
        expect(controller.summary.totalBlocks, 1);
        await repository.clearAllData();
        await pumpEventQueue();
        expect(controller.summary.totalBlocks, 0);
        expect((await repository.getUsageStats()).totalBlockedLifetime, 0);
      },
    );

    test(
        'init seeds initial default rules, whitelist, and settings on clean launch',
        () async {
      final rules = await repository.getRules();
      expect(rules.length, greaterThanOrEqualTo(5));

      final packageNames = rules.map((r) => r.packageName).toList();
      expect(packageNames, contains('com.instagram.android'));
      expect(packageNames, contains('com.google.android.youtube'));
      expect(packageNames, contains('com.facebook.katana'));
      expect(packageNames, contains('com.zhiliaoapp.musically'));
      expect(packageNames, contains('com.ss.android.ugc.trill'));

      final whitelist = await repository.getWhitelistItems();
      expect(whitelist.length, greaterThanOrEqualTo(5));

      final settings = await repository.getSettings();
      expect(settings.isMasterEnabled, isTrue);
      expect(settings.defaultHoldDurationSeconds, 7);
    });

    test('Rules CRUD operations succeed', () async {
      // Get rule by package
      final igRule = await repository.getRule('com.instagram.android');
      expect(igRule, isNotNull);
      expect(igRule!.appName, 'Instagram');

      // Update rule
      final updatedIg = igRule.copyWith(
        holdDurationSeconds: 15,
        interventionMode: InterventionMode.strictBlock,
      );
      await repository.saveRule(updatedIg);

      final fetched = await repository.getRule('com.instagram.android');
      expect(fetched!.holdDurationSeconds, 15);
      expect(fetched.interventionMode, InterventionMode.strictBlock);

      // Create new custom rule
      final newRule = RuleModel(
        id: 'reddit',
        packageName: 'com.reddit.frontpage',
        appName: 'Reddit',
      );
      await repository.saveRule(newRule);

      var rules = await repository.getRules();
      expect(rules.any((r) => r.packageName == 'com.reddit.frontpage'), isTrue);

      // Delete rule
      await repository.deleteRule('reddit');
      rules = await repository.getRules();
      expect(
        rules.any((r) => r.packageName == 'com.reddit.frontpage'),
        isFalse,
      );
    });

    test('Schedules CRUD operations succeed', () async {
      final schedule = ScheduleModel(
        id: 'sch_1',
        name: 'Evening Chill',
        daysOfWeek: [1, 2, 3, 4, 5],
        startHour: 20,
        startMinute: 0,
        endHour: 23,
        endMinute: 0,
      );

      await repository.saveSchedule(schedule);

      final fetched = await repository.getSchedule('sch_1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Evening Chill');

      final updated = fetched.copyWith(
        name: 'Night Focus',
        endHour: 23,
        endMinute: 30,
      );
      await repository.saveSchedule(updated);

      final allSchedules = await repository.getSchedules();
      expect(allSchedules.length, 1);
      expect(allSchedules.first.name, 'Night Focus');

      await repository.deleteSchedule('sch_1');
      final afterDelete = await repository.getSchedules();
      expect(afterDelete, isEmpty);
    });

    test('Settings save and retrieval succeed', () async {
      final initial = await repository.getSettings();
      final updated = initial.copyWith(
        themeMode: 'amoled',
        pinLockEnabled: true,
        pinHash: 'sha256_hash_value',
        isOnboardingCompleted: true,
      );

      await repository.saveSettings(updated);

      final reloaded = await repository.getSettings();
      expect(reloaded.themeMode, 'amoled');
      expect(reloaded.pinLockEnabled, isTrue);
      expect(reloaded.pinHash, 'sha256_hash_value');
      expect(reloaded.isOnboardingCompleted, isTrue);
    });

    test('Whitelist CRUD operations succeed', () async {
      final item = WhitelistItem(
        id: 'yt_comments',
        packageName: 'com.google.android.youtube',
        componentId: 'comments_sheet',
        reason: 'Allow reading comments',
        isSystemProtected: false,
      );

      await repository.saveWhitelistItem(item);
      final list = await repository.getWhitelistItems();
      expect(list.any((i) => i.id == 'yt_comments'), isTrue);

      await repository.deleteWhitelistItem('yt_comments');
      final listAfter = await repository.getWhitelistItems();
      expect(listAfter.any((i) => i.id == 'yt_comments'), isFalse);
    });

    test(
      'History logs append, paginate, filter, and clear correctly',
      () async {
        final now = DateTime.now();

        for (int i = 0; i < 15; i++) {
          final log = HistoryLog(
            id: 'log_$i',
            timestamp: now.subtract(Duration(minutes: i * 10)),
            packageName: 'com.instagram.android',
            appName: 'Instagram',
            interventionMode: InterventionMode.mindfulPause,
            estimatedTimeSavedSeconds: 45,
          );
          await repository.addHistoryLog(log);
        }

        final top5 = await repository.getHistoryLogs(limit: 5);
        expect(top5.length, 5);
        // Ensure sorted newest first
        expect(top5.first.timestamp.isAfter(top5.last.timestamp), isTrue);

        final sinceLogs = await repository.getHistoryLogs(
          since: now.subtract(const Duration(minutes: 35)),
        );
        expect(sinceLogs.length, 4); // 0m, 10m, 20m, 30m

        await repository.clearHistory();
        final emptyLogs = await repository.getHistoryLogs();
        expect(emptyLogs, isEmpty);
      },
    );

    test(
      'Streak calculation computes current and best streaks accurately',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Create entries across 4 consecutive days (today, yesterday, day-2, day-3)
        for (int i = 0; i < 4; i++) {
          final date = today.subtract(Duration(days: i, hours: -12));
          await repository.addHistoryLog(
            HistoryLog(
              id: 'streak_log_$i',
              timestamp: date,
              packageName: 'com.instagram.android',
              appName: 'Instagram',
              interventionMode: InterventionMode.mindfulPause,
              estimatedTimeSavedSeconds: 45,
            ),
          );
        }

        final currentStreak = await repository.calculateCurrentStreak();
        expect(currentStreak, 4);

        final bestStreak = await repository.calculateBestStreak();
        expect(bestStreak, greaterThanOrEqualTo(4));
      },
    );

    test('Usage stats aggregates metrics and 7-day trend series', () async {
      final now = DateTime.now();

      await repository.addHistoryLog(
        HistoryLog(
          id: 's1',
          timestamp: now,
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          interventionMode: InterventionMode.mindfulPause,
          estimatedTimeSavedSeconds: 60,
        ),
      );

      await repository.addHistoryLog(
        HistoryLog(
          id: 's2',
          timestamp: now,
          packageName: 'com.google.android.youtube',
          appName: 'YouTube Shorts',
          interventionMode: InterventionMode.immediateBack,
          estimatedTimeSavedSeconds: 60,
        ),
      );

      final stats = await repository.getUsageStats();
      expect(stats.totalBlockedLifetime, 2);
      expect(stats.totalBlockedToday, 2);
      expect(stats.totalTimeSavedMinutes, 2);
      expect(stats.blocksByApp['Instagram'], 1);
      expect(stats.blocksByApp['YouTube Shorts'], 1);
      expect(stats.dailyTrends.length, 7);
    });

    test(
        'Backup export generates tamper-proof JSON with valid SHA-256 and import restores state',
        () async {
      // Modify a rule
      final rule = (await repository.getRule('com.instagram.android'))!
          .copyWith(holdDurationSeconds: 14);
      await repository.saveRule(rule);

      // Add a schedule
      await repository.saveSchedule(
        ScheduleModel(
          id: 'backup_test_sch',
          name: 'Backup Test Schedule',
          daysOfWeek: [1, 2],
          startHour: 10,
          startMinute: 0,
          endHour: 12,
          endMinute: 0,
        ),
      );

      // Export backup
      final backupJson = await repository.exportBackup();
      expect(backupJson, isNotEmpty);

      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
      expect(decoded.containsKey('checksum'), isTrue);
      expect(decoded.containsKey('data'), isTrue);

      // Clear all data
      await repository.clearAllData();
      final clearedSchedule = await repository.getSchedule('backup_test_sch');
      expect(clearedSchedule, isNull);

      // Restore backup
      final importSuccess = await repository.importBackup(backupJson);
      expect(importSuccess, isTrue);

      final restoredRule = await repository.getRule('com.instagram.android');
      expect(restoredRule!.holdDurationSeconds, 14);

      final restoredSchedule = await repository.getSchedule('backup_test_sch');
      expect(restoredSchedule, isNotNull);
      expect(restoredSchedule!.name, 'Backup Test Schedule');
    });

    test(
      'Backup import rejects tampered data payload with mismatched checksum',
      () async {
        final backupJson = await repository.exportBackup();
        final Map<String, dynamic> decoded = jsonDecode(backupJson);

        // Tamper with data without updating checksum
        final data = decoded['data'] as Map<String, dynamic>;
        final settings = data['settings'] as Map<String, dynamic>;
        settings['themeMode'] = 'tampered_theme';
        decoded['data'] = settings;

        final tamperedJson = jsonEncode(decoded);
        final importResult = await repository.importBackup(tamperedJson);
        expect(importResult, isFalse);
      },
    );

    test(
        'Backup with a valid checksum but malformed section leaves storage untouched',
        () async {
      final before = await repository.getRules();
      final root =
          jsonDecode(await repository.exportBackup()) as Map<String, dynamic>;
      final data = root['data'] as Map<String, dynamic>;
      data['schedules'] = [42];
      root['checksum'] =
          sha256.convert(utf8.encode(jsonEncode(data))).toString();
      expect(await repository.importBackup(jsonEncode(root)), isFalse);
      expect(await repository.getRules(), before);
    });

    test(
      'Backup export redacts PIN secrets and import preserves device PIN',
      () async {
        final initial = await repository.getSettings();
        await repository.saveSettings(
          initial.copyWith(
            pinLockEnabled: true,
            strictModeEnabled: true,
            pinHash: 'device_hash',
            pinSalt: 'device_salt',
            failedPinAttempts: 2,
            lockoutUntil: DateTime.now().add(const Duration(minutes: 5)),
          ),
        );

        final backupJson = await repository.exportBackup();
        final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
        final exportedSettings = (decoded['data']
            as Map<String, dynamic>)['settings'] as Map<String, dynamic>;

        expect(exportedSettings['pinLockEnabled'], isFalse);
        expect(exportedSettings['strictModeEnabled'], isFalse);
        expect(exportedSettings['pinHash'], isNull);
        expect(exportedSettings['pinSalt'], isNull);
        expect(exportedSettings['failedPinAttempts'], 0);
        expect(exportedSettings['lockoutUntil'], isNull);

        final importSuccess = await repository.importBackup(backupJson);
        expect(importSuccess, isTrue);

        final preserved = await repository.getSettings();
        expect(preserved.pinLockEnabled, isTrue);
        expect(preserved.strictModeEnabled, isTrue);
        expect(preserved.pinHash, 'device_hash');
        expect(preserved.pinSalt, 'device_salt');
        expect(preserved.failedPinAttempts, 2);
        expect(preserved.lockoutUntil, isNotNull);
      },
    );

    test('Backup import rejects enabled PIN without credentials', () async {
      final backupJson = await repository.exportBackup();
      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final exportedSettings = data['settings'] as Map<String, dynamic>;
      exportedSettings['pinLockEnabled'] = true;
      exportedSettings['pinHash'] = null;
      exportedSettings['pinSalt'] = null;
      data['settings'] = exportedSettings;
      decoded['checksum'] =
          sha256.convert(utf8.encode(jsonEncode(data))).toString();

      final importResult = await repository.importBackup(jsonEncode(decoded));
      expect(importResult, isFalse);
    });
    test(
      'clearAllData wipes all collections and reseeds default records',
      () async {
        await repository.clearAllData();

        final rules = await repository.getRules();
        expect(rules.length, greaterThanOrEqualTo(5));

        final schedules = await repository.getSchedules();
        expect(schedules, isEmpty);

        final history = await repository.getHistoryLogs();
        expect(history, isEmpty);
      },
    );
  });
}
