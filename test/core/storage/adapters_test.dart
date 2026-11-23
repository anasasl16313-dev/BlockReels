import 'dart:io';
import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/models/whitelist_item.dart';
import 'package:block_reels/core/storage/adapters/hive_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_adapters_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(InterventionModeAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RuleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ScheduleModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HistoryLogAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WhitelistItemAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Hive Manual TypeAdapters Tests (TypeIds 0..5)', () {
    test('InterventionModeAdapter (typeId: 0) serializes and deserializes',
        () async {
      final box = await Hive.openBox<InterventionMode>('test_mode_box');
      await box.put('mode1', InterventionMode.mindfulPause);
      await box.put('mode2', InterventionMode.strictBlock);
      await box.put('mode3', InterventionMode.immediateBack);

      expect(box.get('mode1'), InterventionMode.mindfulPause);
      expect(box.get('mode2'), InterventionMode.strictBlock);
      expect(box.get('mode3'), InterventionMode.immediateBack);
      await box.close();
    });

    test('RuleModelAdapter (typeId: 1) serializes and deserializes', () async {
      final box = await Hive.openBox<RuleModel>('test_rules_box');
      final rule = RuleModel(
        id: 'instagram',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isEnabled: true,
        interventionMode: InterventionMode.mindfulPause,
        holdDurationSeconds: 10,
        dailyQuotaMinutes: 20,
        dailyReelLimit: 5,
        allowChatAndDMs: true,
        allowProfileGrids: true,
        blockEntireApp: false,
        customMessage: 'Be mindful today',
      );

      await box.put('instagram', rule);
      final restored = box.get('instagram');

      expect(restored, isNotNull);
      expect(restored!.id, rule.id);
      expect(restored.packageName, rule.packageName);
      expect(restored.appName, rule.appName);
      expect(restored.isEnabled, rule.isEnabled);
      expect(restored.interventionMode, rule.interventionMode);
      expect(restored.holdDurationSeconds, rule.holdDurationSeconds);
      expect(restored.dailyQuotaMinutes, rule.dailyQuotaMinutes);
      expect(restored.dailyReelLimit, rule.dailyReelLimit);
      expect(restored.allowChatAndDMs, rule.allowChatAndDMs);
      expect(restored.allowProfileGrids, rule.allowProfileGrids);
      expect(restored.blockEntireApp, rule.blockEntireApp);
      expect(restored.customMessage, rule.customMessage);
      await box.close();
    });

    test('ScheduleModelAdapter (typeId: 2) serializes and deserializes',
        () async {
      final box = await Hive.openBox<ScheduleModel>('test_schedules_box');
      final schedule = ScheduleModel(
        id: 'work_focus',
        name: 'Work Focus',
        daysOfWeek: [1, 2, 3, 4, 5],
        startHour: 9,
        startMinute: 15,
        endHour: 17,
        endMinute: 45,
        targetPackageNames: [
          'com.instagram.android',
          'com.google.android.youtube'
        ],
        isActive: true,
        overrideMode: InterventionMode.strictBlock,
      );

      await box.put('work_focus', schedule);
      final restored = box.get('work_focus');

      expect(restored, isNotNull);
      expect(restored!.id, schedule.id);
      expect(restored.name, schedule.name);
      expect(restored.daysOfWeek, schedule.daysOfWeek);
      expect(restored.startHour, schedule.startHour);
      expect(restored.startMinute, schedule.startMinute);
      expect(restored.endHour, schedule.endHour);
      expect(restored.endMinute, schedule.endMinute);
      expect(restored.targetPackageNames, schedule.targetPackageNames);
      expect(restored.isActive, schedule.isActive);
      expect(restored.overrideMode, schedule.overrideMode);
      await box.close();
    });

    test('HistoryLogAdapter (typeId: 3) serializes and deserializes', () async {
      final box = await Hive.openBox<HistoryLog>('test_history_box');
      final log = HistoryLog(
        id: 'hist_1',
        timestamp: DateTime(2026, 8, 15, 12, 0),
        packageName: 'com.zhiliaoapp.musically',
        appName: 'TikTok',
        interventionMode: InterventionMode.mindfulPause,
        estimatedTimeSavedSeconds: 50,
        wasDismissedWithHold: true,
        detectionReason: 'SURGICAL_HEURISTIC',
        wasOverridden: true,
      );

      await box.put('hist_1', log);
      final restored = box.get('hist_1');

      expect(restored, isNotNull);
      expect(restored!.id, log.id);
      expect(restored.packageName, log.packageName);
      expect(restored.appName, log.appName);
      expect(restored.interventionMode, log.interventionMode);
      expect(restored.estimatedTimeSavedSeconds, log.estimatedTimeSavedSeconds);
      expect(restored.wasDismissedWithHold, log.wasDismissedWithHold);
      expect(restored.detectionReason, log.detectionReason);
      expect(restored.wasOverridden, log.wasOverridden);
      await box.close();
    });

    test('AppSettingsAdapter (typeId: 4) serializes and deserializes',
        () async {
      final box = await Hive.openBox<AppSettings>('test_settings_box');
      final settings = AppSettings(
        isMasterEnabled: true,
        themeMode: 'amoled',
        pinLockEnabled: true,
        strictModeEnabled: true,
        pinHash: 'test_hash_val',
        pinSalt: 'test_salt_val',
        failedPinAttempts: 2,
        defaultHoldDurationSeconds: 15,
        breathingTechnique: 'coherent_5_5',
        hapticFeedbackEnabled: true,
        soundDuckingEnabled: false,
        isOnboardingCompleted: true,
        isForegroundServiceEnabled: true,
        schemaVersion: 1,
        dailyTimeSavedGoalMinutes: 75,
        defaultInterventionMode: InterventionMode.strictBlock,
      );

      await box.put('singleton', settings);
      final restored = box.get('singleton');

      expect(restored, isNotNull);
      expect(restored!.isMasterEnabled, settings.isMasterEnabled);
      expect(restored.themeMode, settings.themeMode);
      expect(restored.pinLockEnabled, settings.pinLockEnabled);
      expect(restored.strictModeEnabled, settings.strictModeEnabled);
      expect(restored.pinHash, settings.pinHash);
      expect(restored.pinSalt, settings.pinSalt);
      expect(restored.failedPinAttempts, settings.failedPinAttempts);
      expect(restored.defaultHoldDurationSeconds,
          settings.defaultHoldDurationSeconds);
      expect(restored.breathingTechnique, settings.breathingTechnique);
      expect(restored.hapticFeedbackEnabled, settings.hapticFeedbackEnabled);
      expect(restored.soundDuckingEnabled, settings.soundDuckingEnabled);
      expect(restored.isOnboardingCompleted, settings.isOnboardingCompleted);
      expect(restored.isForegroundServiceEnabled,
          settings.isForegroundServiceEnabled);
      expect(restored.schemaVersion, settings.schemaVersion);
      expect(restored.dailyTimeSavedGoalMinutes,
          settings.dailyTimeSavedGoalMinutes);
      expect(
          restored.defaultInterventionMode, settings.defaultInterventionMode);
      await box.close();
    });

    test('WhitelistItemAdapter (typeId: 5) serializes and deserializes',
        () async {
      final box = await Hive.openBox<WhitelistItem>('test_whitelist_box');
      final item = WhitelistItem(
        id: 'whitelist_1',
        packageName: 'com.instagram.android',
        componentId: 'direct_thread',
        viewIdPattern: 'id/direct_thread_feed',
        reason: 'Allow direct messaging',
        addedAt: DateTime(2026, 8, 1, 10, 0),
        isEnabled: true,
        isSystemProtected: true,
      );

      await box.put('whitelist_1', item);
      final restored = box.get('whitelist_1');

      expect(restored, isNotNull);
      expect(restored!.id, item.id);
      expect(restored.packageName, item.packageName);
      expect(restored.componentId, item.componentId);
      expect(restored.viewIdPattern, item.viewIdPattern);
      expect(restored.reason, item.reason);
      expect(restored.isEnabled, item.isEnabled);
      expect(restored.isSystemProtected, item.isSystemProtected);
      await box.close();
    });
  });
}
