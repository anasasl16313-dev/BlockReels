import 'dart:io';

import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorageRepository repository;
  late AppSettings protectedSettings;
  late StateError openError;
  String? failingBox;
  late Map<String, int> openCalls;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_init_test_');
    openError = StateError('Temporary open failure');
    failingBox = null;
    openCalls = {};
    Future<Box<T>> openBox<T>(String name) async {
      openCalls[name] = (openCalls[name] ?? 0) + 1;
      if (name == failingBox) {
        failingBox = null;
        throw openError;
      }
      return Hive.openBox<T>(name, crashRecovery: false);
    }

    repository = HiveStorageRepository(openBox: openBox);
    await repository.init(customPath: tempDir.path);
    await repository.saveRule(RuleModel(
      id: 'saved',
      packageName: 'saved.app',
      appName: 'Saved app',
      holdDurationSeconds: 19,
    ));
    await repository.saveSchedule(ScheduleModel(
      id: 'saved_schedule',
      name: 'Saved schedule',
      daysOfWeek: [1, 3],
      startHour: 9,
      startMinute: 0,
      endHour: 17,
      endMinute: 0,
      targetPackageNames: ['saved.app'],
    ));
    protectedSettings = (await repository.getSettings()).copyWith(
      pinLockEnabled: true,
      strictModeEnabled: true,
      pinHash: 'existing_device_hash',
      pinSalt: 'existing_device_salt',
      failedPinAttempts: 5,
      lockoutUntil: DateTime(2026, 11, 1, 12),
      isOnboardingCompleted: true,
    );
    await repository.saveSettings(protectedSettings);
    await repository.close();
    openCalls.clear();
  });

  tearDown(() async {
    await repository.close();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  File boxFile(String name) => File('${tempDir.path}/$name.hive');

  test('failed open preserves the original data and retry reuses healthy boxes',
      () async {
    final file = boxFile(HiveStorageRepository.boxSchedulesName);
    final originalBytes = await file.readAsBytes();
    failingBox = HiveStorageRepository.boxSchedulesName;

    await expectLater(
        repository.init(customPath: tempDir.path), throwsA(same(openError)));

    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), originalBytes);
    expect(Hive.isBoxOpen(HiveStorageRepository.boxRulesName), isTrue);
    final rules = Hive.box<RuleModel>(HiveStorageRepository.boxRulesName);
    expect(rules.get('saved.app')!.holdDurationSeconds, 19);
    await expectLater(repository.getSchedules(), throwsStateError);

    await repository.init(customPath: tempDir.path);

    expect(
        Hive.box<RuleModel>(HiveStorageRepository.boxRulesName), same(rules));
    expect(openCalls[HiveStorageRepository.boxRulesName], 1);
    expect(openCalls[HiveStorageRepository.boxSchedulesName], 2);
    expect((await repository.getSchedule('saved_schedule'))!.name,
        'Saved schedule');
    expect((await repository.getRule('saved.app'))!.holdDurationSeconds, 19);
  });

  test('settings open failure cannot seed or expose an unprotected default',
      () async {
    final file = boxFile(HiveStorageRepository.boxSettingsName);
    final originalBytes = await file.readAsBytes();
    failingBox = HiveStorageRepository.boxSettingsName;

    await expectLater(
        repository.init(customPath: tempDir.path), throwsA(same(openError)));

    expect(await file.readAsBytes(), originalBytes);
    expect(Hive.isBoxOpen(HiveStorageRepository.boxSettingsName), isFalse);
    await expectLater(repository.getSettings(), throwsStateError);
    await expectLater(repository.saveSettings(AppSettings()), throwsStateError);
    expect(await file.readAsBytes(), originalBytes);

    await repository.init(customPath: tempDir.path);

    final restored = await repository.getSettings();
    expect(restored.pinLockEnabled, isTrue);
    expect(restored.strictModeEnabled, isTrue);
    expect(restored.pinHash, protectedSettings.pinHash);
    expect(restored.pinSalt, protectedSettings.pinSalt);
    expect(restored.failedPinAttempts, protectedSettings.failedPinAttempts);
    expect(restored.lockoutUntil, protectedSettings.lockoutUntil);
    expect(restored.isOnboardingCompleted, isTrue);
    expect(openCalls[HiveStorageRepository.boxSettingsName], 2);
  });

  test('a late open failure stays unavailable until a successful retry',
      () async {
    failingBox = HiveStorageRepository.boxWhitelistName;
    await expectLater(
        repository.init(customPath: tempDir.path), throwsA(same(openError)));

    // Settings are open, but initialization as a whole has not succeeded.
    expect(Hive.isBoxOpen(HiveStorageRepository.boxSettingsName), isTrue);
    await expectLater(repository.getSettings(), throwsStateError);
    await expectLater(repository.saveSettings(AppSettings()), throwsStateError);

    await repository.close();
    await repository.close();
    await repository.init(customPath: tempDir.path);

    expect((await repository.getSettings()).pinHash, protectedSettings.pinHash);
    expect((await repository.getSchedule('saved_schedule'))!.targetPackageNames,
        ['saved.app']);
    expect((await repository.getRule('saved.app'))!.holdDurationSeconds, 19);
  });
}
