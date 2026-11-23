import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/history_log.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/services/restored_protection_sync.dart';
import 'package:block_reels/core/storage/validated_backup.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:block_reels/features/settings/settings.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../test_helpers/fake_services.dart';

class RecoverableBridge extends FakePlatformBridge {
  bool available = false;
  @override
  Future<bool> updateSettings(AppSettings settings) async =>
      available && await super.updateSettings(settings);
}

class RestoreWriteFault {
  int failures = 0;
  bool keepFailing = false;
  int clearedBoxes = 0;
  Completer<void>? entered;
  Completer<void>? release;
}

/// Real Hive storage with a failure at putAll, after clear has changed the box.
class RestoreFaultBox<T> implements Box<T> {
  final Box<T> box;
  final RestoreWriteFault fault;
  RestoreFaultBox(this.box, this.fault);

  @override
  Future<void> putAll(Map<dynamic, T> entries) async {
    final release = fault.release;
    fault.release = null;
    if (release != null) {
      fault.entered!.complete();
      await release.future;
    }
    if (fault.keepFailing || fault.failures > 0) {
      if (fault.failures > 0) fault.failures--;
      throw StateError('Injected restore write failure');
    }
    await box.putAll(entries);
  }

  @override
  Future<int> clear() {
    fault.clearedBoxes++;
    return box.clear();
  }

  @override
  bool get isEmpty => box.isEmpty;
  @override
  Iterable<T> get values => box.values;
  @override
  Map<dynamic, T> toMap() => box.toMap();
  @override
  T? get(dynamic key, {T? defaultValue}) =>
      box.get(key, defaultValue: defaultValue);
  @override
  bool containsKey(dynamic key) => box.containsKey(key);
  @override
  Future<void> put(dynamic key, T value) => box.put(key, value);
  @override
  Future<void> delete(dynamic key) => box.delete(key);
  @override
  Future<void> flush() => box.flush();
  @override
  Future<void> close() => box.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String backupText(Map<String, dynamic> data, {Object? version = 1}) =>
    jsonEncode({
      'version': version,
      'data': data,
      'checksum': sha256.convert(utf8.encode(jsonEncode(data))).toString(),
    });

void main() {
  late Directory directory;
  late HiveStorageRepository repository;
  late RestoreWriteFault fault;
  late AppSettings security;
  late HistoryLog originalLog;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup_restore_test_');
    fault = RestoreWriteFault();
    Future<Box<T>> open<T>(String name) async {
      final box = await Hive.openBox<T>(name, crashRecovery: false);
      return name == HiveStorageRepository.boxRulesName
          ? RestoreFaultBox(box, fault)
          : box;
    }

    repository = HiveStorageRepository(openBox: open);
    await repository.init(customPath: directory.path);
    security = (await repository.getSettings()).copyWith(
      pinLockEnabled: true,
      strictModeEnabled: true,
      pinHash: 'private_device_hash',
      pinSalt: 'private_device_salt',
      failedPinAttempts: 5,
      lockoutUntil: DateTime(2026, 11, 2, 12),
      isOnboardingCompleted: true,
    );
    await repository.saveSettings(security);
    await repository.saveRule(RuleModel(
      id: 'original',
      packageName: 'original.app',
      appName: 'Original app',
      holdDurationSeconds: 19,
    ));
    await repository.saveSchedule(ScheduleModel(
      id: 'original',
      name: 'Original schedule',
      daysOfWeek: [1, 3],
      startHour: 22,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
      targetPackageNames: ['original.app'],
    ));
    originalLog = HistoryLog(
      id: 'original',
      timestamp: DateTime(2026, 10, 30, 9),
      packageName: 'original.app',
      appName: 'Original app',
      interventionMode: InterventionMode.mindfulPause,
    );
    await repository.addHistoryLog(originalLog);
  });

  tearDown(() async {
    await repository.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<Map<String, dynamic>> exportedData() async =>
      (jsonDecode(await repository.exportBackup())
          as Map<String, dynamic>)['data'] as Map<String, dynamic>;

  Future<void> expectSecurityPreserved() async {
    final actual = await repository.getSettings();
    expect(actual.pinLockEnabled, security.pinLockEnabled);
    expect(actual.strictModeEnabled, security.strictModeEnabled);
    expect(actual.pinHash, security.pinHash);
    expect(actual.pinSalt, security.pinSalt);
    expect(actual.failedPinAttempts, security.failedPinAttempts);
    expect(actual.lockoutUntil, security.lockoutUntil);
  }

  test('oversized backups and long nested fields never modify stored data', () async {
    final before = await exportedData();
    for (final input in [
      ' ' * (ValidatedBackup.maxCharacters + 1),
      backupText({'rules': List.filled(ValidatedBackup.maxRecords + 1, null)}),
      backupText({'settings': {'unused': 's' * 4097}}),
    ]) {
      expect(await repository.importBackup(input), isFalse);
    }
    expect(await exportedData(), before);
    expect(repository.pendingProtectionSync, isNull);
  });

  test('cold start retries failed Android sync and preserves deliberately empty rules', () async {
    expect(await repository.importBackup(backupText({
      'rules': [],
      'settings': {'isOnboardingCompleted': false},
    })), isTrue);
    final bridge = RecoverableBridge();
    addTearDown(bridge.dispose);
    await expectLater(RestoredProtectionSync.reconcile(repository, bridge), throwsStateError);
    final revision = repository.pendingProtectionSync;
    expect(revision, isNotNull);
    await repository.close();
    repository = HiveStorageRepository();
    await repository.init(customPath: directory.path);
    expect(repository.pendingProtectionSync, revision);
    bridge.available = true;
    await RestoredProtectionSync.reconcile(repository, bridge);
    expect(bridge.syncRulesCalls.last, isEmpty);
    expect(repository.pendingProtectionSync, isNull);
    expect((await repository.getSettings()).isOnboardingCompleted, isTrue);
    expect((await repository.getHistoryLogs()).single.id, originalLog.id);
    await expectSecurityPreserved();
  });

  test('invalid global duration and backup version never mutate storage',
      () async {
    final before = await exportedData();
    for (final duration in [-1, 0, 4, 31, 300]) {
      expect(
          await repository.importBackup(backupText({
            'settings': {'defaultHoldDurationSeconds': duration},
            'rules': [],
          })),
          isFalse);
    }
    for (final version in [null, 0, 2, '1']) {
      expect(
          await repository
              .importBackup(backupText({'rules': []}, version: version)),
          isFalse);
    }
    expect(await exportedData(), before);
    await expectSecurityPreserved();
  });

  test('checksum-valid invalid identifiers and schedule values are rejected',
      () async {
    final before = await exportedData();
    final rule = RuleModel(id: 'r', packageName: 'regional.app', appName: 'App')
        .toJson();
    final schedule = (await repository.getSchedules()).single.toJson();
    final invalid = <Map<String, dynamic>>[
      {
        'rules': [
          {...rule, 'id': '  '}
        ]
      },
      {
        'rules': [
          {...rule, 'packageName': ''}
        ]
      },
      {
        'rules': [
          rule,
          {...rule, 'id': 'another'}
        ]
      },
      {
        'rules': [
          rule,
          {...rule, 'packageName': 'other.app'}
        ]
      },
      {
        'schedules': [schedule, schedule]
      },
      {
        'schedules': [
          {...schedule, 'id': ''}
        ]
      },
      for (final days in [
        [0],
        [8],
        [1, 1]
      ])
        {
          'schedules': [
            {...schedule, 'daysOfWeek': days}
          ]
        },
      for (final field in ['startHour', 'endHour'])
        {
          'schedules': [
            {...schedule, field: 24}
          ]
        },
      for (final field in ['startMinute', 'endMinute'])
        {
          'schedules': [
            {...schedule, field: -1}
          ]
        },
      {
        'whitelist': [
          {'id': '', 'packageName': 'app', 'componentId': 'chat'}
        ]
      },
      {
        'history': [
          {...originalLog.toJson(), 'id': ''}
        ]
      },
      {
        'history': [originalLog.toJson(), originalLog.toJson()]
      },
    ];
    for (final data in invalid) {
      expect(await repository.importBackup(backupText(data)), isFalse);
    }
    expect(await exportedData(), before);
    expect(await repository.getHistoryLogs(), [originalLog]);
  });

  test('version 1 legacy aliases and unfamiliar regional packages normalize',
      () async {
    const regional = 'com.ss.android.ugc.trill';
    for (final packagesField in [
      'enabledPackageNames',
      'enabledPackages',
      'enabledApps'
    ]) {
      final data = {
        'rules': [
          {
            'packageName': regional,
            'appName': 'Regional app',
            'mode': 'STRICT_BLOCK'
          },
          {
            'id': 'local',
            'packageName': 'com.local.video.region',
            'appName': 'Local'
          },
        ],
        'schedules': [
          {
            'id': 'legacy',
            'title': 'Legacy schedule',
            packagesField: [regional, 'com.local.video.region'],
          },
        ],
        'settings': {
          'isMasterSwitchEnabled': false,
          'isHapticFeedbackEnabled': false,
          'defaultHoldDurationSeconds': 5,
        },
        'whitelist': [
          {
            'id': 'chat',
            'packageName': regional,
            'exclusionType': 'chat',
            'description': 'Legacy chat'
          },
        ],
        'history': [
          {
            ...originalLog.toJson(),
            'timestamp': originalLog.timestamp.millisecondsSinceEpoch,
            'appName': null,
            'appType': 'Legacy app'
          },
        ],
      };
      expect(await repository.importBackup(backupText(data)), isTrue);
      expect((await repository.getRule(regional))!.id, regional);
      expect((await repository.getRule(regional))!.interventionMode,
          InterventionMode.strictBlock);
      final restored = (await repository.getSchedules()).single;
      expect(restored.name, 'Legacy schedule');
      expect(restored.targetPackageNames, [regional, 'com.local.video.region']);
      expect((await repository.getSettings()).isMasterEnabled, isFalse);
      expect((await repository.getWhitelistItems()).single.componentId, 'chat');
      expect((await repository.getHistoryLogs()).single.appName, 'Legacy app');
      await expectSecurityPreserved();
    }
  });

  test('failure after the first mutation rolls back and skips native sync',
      () async {
    final before = await exportedData();
    final bridge = FakePlatformBridge();
    final container = ProviderContainer(overrides: [
      storageRepositoryProvider.overrideWithValue(repository),
      platformBridgeProvider.overrideWithValue(bridge),
    ]);
    await container.read(settingsProvider.notifier).loadSettings();
    var refreshed = false;
    final controller = SettingsController(
      repository,
      container.read(settingsProvider.notifier),
      bridge: bridge,
      onDataRestored: () async => refreshed = true,
    );
    addTearDown(() async {
      controller.dispose();
      container.dispose();
      await bridge.dispose();
    });
    fault.failures = 1;
    final pinStates = <bool>[];
    final changes = Hive.box<AppSettings>(HiveStorageRepository.boxSettingsName)
        .watch()
        .listen((event) => pinStates.add(
            !event.deleted && (event.value as AppSettings).pinLockEnabled));
    addTearDown(changes.cancel);
    expect(await controller.importBackup(backupText({'rules': []})), isFalse);
    expect(fault.clearedBoxes, greaterThanOrEqualTo(2));
    expect(await exportedData(), before);
    expect(await repository.getHistoryLogs(), [originalLog]);
    await expectSecurityPreserved();
    await pumpEventQueue();
    expect(pinStates, isEmpty, reason: 'A rules-only rollback must never write PIN settings');
    expect(bridge.syncRulesCalls, isEmpty);
    expect(bridge.updateSettingsCalls, isEmpty);
    expect(refreshed, isFalse);
  });

  test('restart recovers a durable journal before seeding or normal reads',
      () async {
    final before = await exportedData();
    fault.keepFailing = true;
    expect(await repository.importBackup(backupText({'rules': []})), isFalse);
    expect(Hive.box<RuleModel>(HiveStorageRepository.boxRulesName).isEmpty,
        isTrue);
    await expectLater(repository.getSettings(), throwsStateError);
    await expectLater(repository.saveSettings(AppSettings()), throwsStateError);
    await repository.close();
    await Hive.close();

    repository = HiveStorageRepository();
    await repository.init(customPath: directory.path);

    expect(await exportedData(), before);
    expect((await repository.getRule('original.app'))!.holdDurationSeconds, 19);
    expect(await repository.getHistoryLogs(), [originalLog]);
    await expectSecurityPreserved();
    expect(Hive.box<String>('box_restore_journal').isEmpty, isTrue);
  });

  test('concurrent writes wait for restoration and then survive', () async {
    final release = Completer<void>();
    fault.release = release;
    fault.entered = Completer<void>();
    final restoring = repository.importBackup(backupText({
      'rules': [],
      'settings': {'themeMode': 'dark'},
      'history': [],
    }));
    await fault.entered!.future;
    var saved = false;
    final saveRule = repository
        .saveRule(RuleModel(
          id: 'concurrent',
          packageName: 'concurrent.app',
          appName: 'Concurrent',
        ))
        .then((_) => saved = true);
    final saveSettings =
        repository.saveSettings(security.copyWith(themeMode: 'amoled'));
    final record = repository.addHistoryLog(originalLog);
    await pumpEventQueue();
    expect(saved, isFalse);
    release.complete();
    expect(await restoring, isTrue);
    await Future.wait([saveRule, saveSettings, record]);
    expect((await repository.getRule('concurrent.app'))!.id, 'concurrent');
    expect((await repository.getSettings()).themeMode, 'amoled');
    expect(await repository.getHistoryLogs(), [originalLog]);
    await expectSecurityPreserved();
  });

  test('settings-only export preserves history and excludes private secrets',
      () async {
    final text = await repository.exportBackup();
    final data = (jsonDecode(text) as Map<String, dynamic>)['data'] as Map;
    expect(data.containsKey('history'), isFalse);
    expect(text, isNot(contains(security.pinHash)));
    expect(text, isNot(contains(security.pinSalt)));
    expect(text, isNot(contains('pending_restore')));
    expect(await repository.importBackup(text), isTrue);
    expect(await repository.getHistoryLogs(), [originalLog]);
    await expectSecurityPreserved();
  });

  test('explicit history backups remain supported and successful restore syncs',
      () async {
    final bridge = FakePlatformBridge();
    final container = ProviderContainer(overrides: [
      storageRepositoryProvider.overrideWithValue(repository),
      platformBridgeProvider.overrideWithValue(bridge),
    ]);
    await container.read(settingsProvider.notifier).loadSettings();
    final controller = SettingsController(
      repository,
      container.read(settingsProvider.notifier),
      bridge: bridge,
    );
    addTearDown(() async {
      controller.dispose();
      container.dispose();
      await bridge.dispose();
    });
    final incoming = originalLog.copyWith(id: 'imported');
    expect(
        await controller.importBackup(backupText({
          'settings': {
            'defaultHoldDurationSeconds': 30,
            'pinLockEnabled': false
          },
          'history': [incoming.toJson()],
        })),
        isTrue);
    expect(await repository.getHistoryLogs(), [incoming]);
    expect(bridge.syncRulesCalls, isNotEmpty);
    expect(bridge.syncSchedulesCalls, isNotEmpty);
    expect(bridge.updateSettingsCalls.last.defaultHoldDurationSeconds, 30);
    expect(bridge.updateSettingsCalls.last.pinHash, security.pinHash);
    await expectSecurityPreserved();
    expect(await controller.importBackup(backupText({'history': []})), isTrue);
    expect(await repository.getHistoryLogs(), isEmpty);
  });
}
