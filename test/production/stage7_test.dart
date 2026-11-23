import 'dart:convert';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/platform_channel/dtos/schedule_dto.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/features/schedules/schedules.dart';
import 'package:block_reels/features/dashboard/domain/models/protection_status.dart';
import 'package:block_reels/features/settings/settings.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/fake_services.dart';

class FailingScheduleStorage extends FakeStorageRepository {
  bool fail = false;
  @override
  Future<void> saveSchedule(ScheduleModel schedule) async {
    if (fail) throw StateError('disk');
    await super.saveSchedule(schedule);
  }
}

class FailingScheduleBridge extends FakePlatformBridge {
  bool fail = false;
  @override
  Future<bool> syncSchedules(List<ScheduleDto> schedules) async {
    await super.syncSchedules(schedules);
    return !fail;
  }
}

void main() {
  const rule = ScheduleRuleModel(
      id: 'work',
      name: 'Work',
      daysOfWeek: [1, 3],
      startHour: 22,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
      enabledPackageNames: ['com.instagram.android']);

  testWidgets('scheduled window distinguishes effective from paused protection',
      (tester) async {
    final now = DateTime.now();
    // Leave enough margin for slow widget rendering under a full test run.
    final start = now.subtract(const Duration(hours: 6));
    final end = now.add(const Duration(hours: 6));
    final current = ScheduleRuleModel(
        id: 'current',
        name: 'Current',
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
        startHour: start.hour,
        startMinute: start.minute,
        endHour: end.hour,
        endMinute: end.minute,
        enabledPackageNames: const []);
    const scheduled = ProtectionStatus(
        kind: ProtectionStatusKind.scheduled,
        title: 'Active',
        reason: '',
        activeScheduleNames: ['Current']);
    const paused = ProtectionStatus(
        kind: ProtectionStatusKind.paused, title: 'Paused', reason: '');
    Widget card(ProtectionStatus status,
            {bool syncPending = false}) =>
        MaterialApp(
            home: Scaffold(
                body: ScheduleCard(
                    schedule: current,
                    onToggle: (_) {},
                    onDelete: () {},
                    syncPending: syncPending,
                    protectionStatus: status)));
    await tester.pumpWidget(card(scheduled));
    expect(find.text('Blocking during this schedule now'), findsOneWidget);
    await tester.pumpWidget(card(scheduled, syncPending: true));
    expect(find.textContaining('protection sync is pending'), findsOneWidget);
    expect(find.text('Blocking during this schedule now'), findsNothing);
    await tester.pumpWidget(card(paused));
    expect(find.textContaining('this schedule is not currently applied'),
        findsOneWidget);
  });

  testWidgets(
      'schedule describes days, overnight and apps; deletion requires confirmation',
      (tester) async {
    final storage = FakeStorageRepository();
    final bridge = FakePlatformBridge();
    final controller = SchedulesController(bridge, storage);
    await tester.pump();
    await tester.runAsync(() => controller.addSchedule(rule));
    addTearDown(() async {
      controller.dispose();
      await bridge.dispose();
    });
    await tester
        .pumpWidget(MaterialApp(home: SchedulesScreen(controller: controller)));
    expect(find.textContaining('Mon, Wed'), findsOneWidget);
    expect(find.textContaining('ends next day'), findsOneWidget);
    expect(find.text('Apps: Instagram'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_delete_work')));
    await tester.pumpAndSettle();
    expect(storage.schedules, contains('work'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.schedules, contains('work'));
    await tester.tap(find.byKey(const Key('btn_delete_work')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_schedule')));
    await tester.pumpAndSettle();
    expect(storage.schedules, isEmpty);
    expect(bridge.syncSchedulesCalls.last, isEmpty);
  });

  testWidgets('storage failure keeps editor open and reports failure',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final storage = FailingScheduleStorage()..fail = true;
    final bridge = FakePlatformBridge();
    final controller = SchedulesController(bridge, storage);
    addTearDown(() async {
      controller.dispose();
      await bridge.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: SchedulesScreen(controller: controller),
    ));
    await tester.tap(find.byKey(const Key('empty_add_schedule')));
    await tester.pumpAndSettle();
    expect(find.text('All supported apps'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_save_schedule')));
    await tester.pumpAndSettle();
    expect(find.text('Could not save the schedule. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(storage.schedules, isEmpty);
    expect(find.text('Schedule saved'), findsNothing);
  });

  testWidgets('specific-app selection requires an app and persists it',
      (tester) async {
    final storage = FakeStorageRepository();
    final bridge = FakePlatformBridge();
    final controller = SchedulesController(bridge, storage);
    addTearDown(() async {
      controller.dispose();
      await bridge.dispose();
    });
    await tester
        .pumpWidget(MaterialApp(home: SchedulesScreen(controller: controller)));
    await tester.tap(find.byKey(const Key('empty_add_schedule')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose specific apps'));
    await tester.tap(find.text('Choose specific apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_save_schedule')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.text('Select at least one app, or choose all supported apps.'));
    expect(find.text('Select at least one app, or choose all supported apps.'),
        findsOneWidget);
    expect(storage.schedules, isEmpty);
    await tester.ensureVisible(
        find.byKey(const Key('schedule_app_com.instagram.android')));
    await tester
        .tap(find.byKey(const Key('schedule_app_com.instagram.android')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('btn_save_schedule')));
    await tester.pumpAndSettle();
    expect(storage.schedules.values.single.targetPackageNames,
        ['com.instagram.android']);
    expect(find.text('Schedule saved'), findsOneWidget);
  });

  testWidgets('clipboard validation precedes restore confirmation and mutation',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var clipboard = '';
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
        return null;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final storage = FakeStorageRepository();
    await storage
        .saveRule(RuleModel(id: 'ig', packageName: 'ig', appName: 'Instagram'));
    final bridge = FakePlatformBridge();
    final container = ProviderContainer(overrides: [
      storageRepositoryProvider.overrideWithValue(storage),
      platformBridgeProvider.overrideWithValue(bridge)
    ]);
    await container.read(settingsProvider.notifier).loadSettings();
    final controller =
        SettingsController(storage, container.read(settingsProvider.notifier));
    addTearDown(() async {
      controller.dispose();
      container.dispose();
      await bridge.dispose();
    });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: SettingsScreen(controller: controller),
    ));
    Future<void> tapRestore() async {
      final button = find.byKey(const Key('btn_import_backup'));
      await tester.scrollUntilVisible(button, 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await tapRestore();
    expect(find.textContaining('Clipboard is empty'), findsOneWidget);
    expect(storage.rules, contains('ig'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    clipboard = 'broken';
    await tapRestore();
    expect(find.textContaining('invalid or damaged'), findsOneWidget);
    expect(find.byKey(const Key('confirm_restore_backup')), findsNothing);
    expect(storage.rules, contains('ig'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final backup = await storage.exportBackup();
    clipboard = backup;
    await tapRestore();
    expect(find.byKey(const Key('confirm_restore_backup')), findsOneWidget);
    expect(find.textContaining('will clear your existing activity history'),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.rules, contains('ig'));
    await storage.saveRule(
        RuleModel(id: 'other', packageName: 'other', appName: 'Other'));
    await tapRestore();
    await tester.tap(find.byKey(const Key('confirm_restore_backup')));
    await tester.pumpAndSettle();
    expect(storage.rules, contains('ig'));
    expect(storage.rules, isNot(contains('other')));
    expect(find.text('Backup restored'), findsOneWidget);
  });

  test('checksum-valid malformed sections are rejected before any mutation',
      () async {
    final storage = FakeStorageRepository();
    await storage
        .saveRule(RuleModel(id: 'ig', packageName: 'ig', appName: 'Instagram'));
    final root =
        jsonDecode(await storage.exportBackup()) as Map<String, dynamic>;
    final data = root['data'] as Map<String, dynamic>;
    data['schedules'] = [42];
    root['checksum'] = sha256.convert(utf8.encode(jsonEncode(data))).toString();
    expect(await storage.importBackup(jsonEncode(root)), isFalse);
    expect(storage.rules, contains('ig'));
  });

  test('schedule sync failure reports that the saved record is local only',
      () async {
    final storage = FakeStorageRepository();
    final bridge = FailingScheduleBridge();
    final controller = SchedulesController(bridge, storage);
    await pumpEventQueue();
    bridge.fail = true;
    expect(await controller.addSchedule(rule), ScheduleWriteResult.syncFailed);
    expect(storage.schedules, contains('work'));
    expect(controller.hasUnsyncedChanges, isTrue);
    bridge.fail = false;
    expect(await controller.updateSchedule(rule), ScheduleWriteResult.success);
    expect(controller.hasUnsyncedChanges, isFalse);
    controller.dispose();
    await bridge.dispose();
  });

  test('restore sync failure does not report full success', () async {
    final storage = FakeStorageRepository();
    final bridge = FailingScheduleBridge();
    final container = ProviderContainer(overrides: [
      storageRepositoryProvider.overrideWithValue(storage),
      platformBridgeProvider.overrideWithValue(bridge),
    ]);
    await container.read(settingsProvider.notifier).loadSettings();
    final controller = SettingsController(
        storage, container.read(settingsProvider.notifier),
        bridge: bridge);
    final backup = await storage.exportBackup();
    bridge.fail = true;
    await expectLater(
        controller.importBackup(backup), throwsA(isA<BackupSyncException>()));
    controller.dispose();
    container.dispose();
    await bridge.dispose();
  });
}
