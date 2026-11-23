import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:block_reels/core/theme/app_theme.dart';
import 'package:block_reels/features/dashboard/dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 27, 10, 30);

  ScheduleModel activeSchedule({
    String id = 'focus',
    String name = 'Deep Focus',
    List<String> targets = const ['com.instagram.android'],
  }) {
    return ScheduleModel(
      id: id,
      name: name,
      daysOfWeek: [now.weekday],
      startHour: 10,
      startMinute: 0,
      endHour: 11,
      endMinute: 0,
      targetPackageNames: targets,
    );
  }

  ProtectionStatus resolve({
    bool ready = true,
    bool service = true,
    bool master = true,
    Map<String, bool> selected = const {'com.instagram.android': true},
    List<ScheduleModel> schedules = const [],
  }) {
    return ProtectionStatusResolver.resolve(
      isReady: ready,
      isAccessibilityServiceActive: service,
      isMasterEnabled: master,
      selectedApps: selected,
      schedules: schedules,
      now: now,
    );
  }

  group('ProtectionStatusResolver native decision order', () {
    test('a Lite-only schedule maps to the selective native target', () {
      final status = resolve(
        selected: const {},
        schedules: [activeSchedule(targets: const ['com.facebook.lite'])],
      );
      expect(status.kind, ProtectionStatusKind.scheduled);
      expect(status.canBlockNow, isTrue);
      expect(status.reason, contains('Facebook Lite'));
    });

    test('reports checking until all inputs are ready', () {
      final status = resolve(ready: false);

      expect(status.kind, ProtectionStatusKind.verifying);
      expect(status.canBlockNow, isFalse);
    });

    test('Accessibility off never claims active protection', () {
      final status = resolve(
        service: false,
        schedules: [activeSchedule()],
      );

      expect(status.kind, ProtectionStatusKind.setupRequired);
      expect(status.action, ProtectionStatusAction.openAccessibility);
      expect(status.canBlockNow, isFalse);
    });

    test('master off pauses both app selections and active schedules', () {
      final status = resolve(
        master: false,
        schedules: [activeSchedule()],
      );

      expect(status.kind, ProtectionStatusKind.paused);
      expect(status.reason, contains('does not apply'));
      expect(status.activeScheduleNames, ['Deep Focus']);
      expect(status.canBlockNow, isFalse);
    });

    test('active schedule overrides an individual app being unselected', () {
      final status = resolve(
        selected: const {'com.instagram.android': false},
        schedules: [activeSchedule()],
      );

      expect(status.kind, ProtectionStatusKind.scheduled);
      expect(status.title, 'Scheduled protection');
      expect(status.selectedAppCount, 0);
      expect(status.reason, contains('overrides individual app selections'));
      expect(status.reason, contains('Instagram'));
      expect(status.canBlockNow, isTrue);
    });

    test('selected apps are active only when no schedule is active', () {
      final futureSchedule = ScheduleModel(
        id: 'later',
        name: 'Later',
        daysOfWeek: [now.weekday],
        startHour: 12,
        startMinute: 0,
        endHour: 13,
        endMinute: 0,
      );
      final status = resolve(schedules: [futureSchedule]);

      expect(status.kind, ProtectionStatusKind.active);
      expect(status.selectedAppCount, 1);
      expect(status.canBlockNow, isTrue);
    });

    test('no selection explains that configured schedules may activate later',
        () {
      final futureSchedule = ScheduleModel(
        id: 'later',
        name: 'Later',
        daysOfWeek: [now.weekday],
        startHour: 12,
        startMinute: 0,
        endHour: 13,
        endMinute: 0,
      );
      final status = resolve(
        selected: const {'com.instagram.android': false},
        schedules: [futureSchedule],
      );

      expect(status.kind, ProtectionStatusKind.paused);
      expect(status.reason, contains('can still turn protection on'));
      expect(status.action, ProtectionStatusAction.openAppControls);
    });
  });

  test('DashboardController refresh tracks service, master, and schedules',
      () async {
    final storage = FakeStorageRepository();
    final bridge = FakePlatformBridge();
    addTearDown(bridge.dispose);
    await storage.saveRule(
      RuleModel(
        id: 'instagram',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isEnabled: false,
      ),
    );
    await storage.saveSchedule(activeSchedule());
    storage.settings = AppSettings(isMasterEnabled: true);

    final controller = DashboardController(
      bridge,
      storage: storage,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    expect(
      controller.state.protectionStatus.kind,
      ProtectionStatusKind.scheduled,
    );

    storage.settings = AppSettings(isMasterEnabled: false);
    await controller.refresh();
    expect(
      controller.state.protectionStatus.kind,
      ProtectionStatusKind.paused,
    );

    bridge.serviceEnabled = false;
    await controller.refresh();
    expect(
      controller.state.protectionStatus.kind,
      ProtectionStatusKind.setupRequired,
    );
  });

  test('DashboardController reacts to app-control and schedule notifiers',
      () async {
    final bridge = FakePlatformBridge();
    final appControlChanges = ValueNotifier<int>(0);
    final scheduleChanges = ValueNotifier<int>(0);
    var masterEnabled = true;
    var selected = <String, bool>{'com.instagram.android': true};
    var schedules = <ScheduleModel>[];
    addTearDown(() async {
      appControlChanges.dispose();
      scheduleChanges.dispose();
      await bridge.dispose();
    });

    final controller = DashboardController(
      bridge,
      appBlockerListenable: appControlChanges,
      readAppToggles: () => selected,
      readMasterEnabled: () => masterEnabled,
      schedulesListenable: scheduleChanges,
      readSchedules: () => schedules,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.state.protectionStatus.kind, ProtectionStatusKind.active);

    masterEnabled = false;
    appControlChanges.value++;
    expect(controller.state.protectionStatus.kind, ProtectionStatusKind.paused);

    masterEnabled = true;
    selected = {'com.instagram.android': false};
    appControlChanges.value++;
    expect(controller.state.protectionStatus.kind, ProtectionStatusKind.paused);

    schedules = [activeSchedule()];
    scheduleChanges.value++;
    expect(
      controller.state.protectionStatus.kind,
      ProtectionStatusKind.scheduled,
    );
  });

  testWidgets('Dashboard refreshes Accessibility after returning from settings',
      (tester) async {
    final storage = FakeStorageRepository();
    final bridge = FakePlatformBridge();
    await storage.saveRule(
      RuleModel(
        id: 'instagram',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
      ),
    );
    final controller = DashboardController(bridge, storage: storage);
    addTearDown(() async {
      controller.dispose();
      await bridge.dispose();
    });
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DashboardScreen(controller: controller),
      ),
    );
    await tester.pump();
    expect(find.text('Blocking active'), findsOneWidget);

    bridge.serviceEnabled = false;
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(find.text('Setup required'), findsOneWidget);
  });
}
