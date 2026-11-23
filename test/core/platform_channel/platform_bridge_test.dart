import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/platform_channel/dtos/intervention_config_dto.dart';
import 'package:block_reels/core/platform_channel/dtos/platform_event.dart';
import 'package:block_reels/core/platform_channel/dtos/schedule_dto.dart';
import 'package:block_reels/core/platform_channel/mock_platform_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockPlatformBridge bridge;

  setUp(() {
    bridge = MockPlatformBridge();
  });

  tearDown(() {
    bridge.dispose();
  });

  group('MockPlatformBridge Contract & Simulation Tests', () {
    test(
        'Queries permission flags and dispatches requests with call count tracking',
        () async {
      expect(await bridge.isAccessibilityServiceEnabled(), isTrue);
      expect(await bridge.isBatteryOptimizationDisabled(), isTrue);
      expect(await bridge.isOverlayPermissionGranted(), isTrue);
      expect(await bridge.isUsageStatsPermissionGranted(), isTrue);
      expect(await bridge.isForegroundServiceRunning(), isFalse);

      await bridge.requestAccessibilityPermission();
      await bridge.requestDisableBatteryOptimization();
      await bridge.requestOverlayPermission();
      await bridge.requestUsageStatsPermission();

      expect(bridge.requestAccessibilityCalls, 1);
      expect(bridge.requestBatteryOptCalls, 1);
      expect(bridge.requestOverlayCalls, 1);
      expect(bridge.requestUsageStatsCalls, 1);
    });

    test(
        'Syncs rules, toggles, config, schedules, and settings recording payload spies',
        () async {
      final rule = RuleModel(
        id: 'instagram',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isEnabled: true,
      );

      await bridge.syncRules([rule]);
      expect(bridge.syncRulesCalls.length, 1);
      expect(bridge.syncRulesCalls.first.first.packageName,
          'com.instagram.android');

      await bridge.syncAppToggles(
          {'com.instagram.android': true, 'com.google.android.youtube': false});
      expect(bridge.syncAppTogglesCalls.length, 1);
      expect(bridge.syncAppTogglesCalls.first['com.instagram.android'], isTrue);
      expect(bridge.syncAppTogglesCalls.first['com.google.android.youtube'],
          isFalse);

      const config = InterventionConfigDto(
        defaultMode: 'MINDFUL_PAUSE',
        holdDurationSeconds: 10,
      );
      await bridge.syncInterventionConfig(config);
      expect(bridge.syncInterventionConfigCalls.length, 1);
      expect(bridge.syncInterventionConfigCalls.first.holdDurationSeconds, 10);

      const schedule = ScheduleDto(
        id: 'sch_1',
        title: 'Morning',
        daysOfWeek: [1, 2],
        startHour: 8,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );
      await bridge.syncSchedules([schedule]);
      expect(bridge.syncSchedulesCalls.length, 1);
      expect(bridge.syncSchedulesCalls.first.first.title, 'Morning');

      final settings = AppSettings(themeMode: 'amoled');
      await bridge.updateSettings(settings);
      expect(bridge.updateSettingsCalls.length, 1);
      expect(bridge.updateSettingsCalls.first.themeMode, 'amoled');
    });

    test('Foreground service start and stop toggles state', () async {
      expect(await bridge.isForegroundServiceRunning(), isFalse);

      await bridge.startForegroundService();
      expect(await bridge.isForegroundServiceRunning(), isTrue);
      expect(bridge.startForegroundCalls, 1);

      await bridge.stopForegroundService();
      expect(await bridge.isForegroundServiceRunning(), isFalse);
      expect(bridge.stopForegroundCalls, 1);
    });

    test('Event simulation dispatches typed events across filtered streams',
        () async {
      final List<PlatformEvent> allEvents = [];
      final List<BlockEvent> blockEvents = [];
      final List<bool> serviceStates = [];

      final sub1 = bridge.eventStream.listen(allEvents.add);
      final sub2 = bridge.blockEventsStream.listen(blockEvents.add);
      final sub3 = bridge.serviceStatusStream.listen(serviceStates.add);

      bridge.simulateBlockEvent(
        packageName: 'com.instagram.android',
        appType: 'Instagram',
        interventionMode: 'MINDFUL_PAUSE',
      );

      bridge.simulateServiceStatusChanged(false);
      bridge.simulateBatteryOptChanged(true);

      await pumpEventQueue();

      expect(allEvents.length, 3);
      expect(blockEvents.length, 1);
      expect(blockEvents.first.packageName, 'com.instagram.android');
      expect(serviceStates.length, 1);
      expect(serviceStates.first, isFalse);

      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    });

    test('reset clears call history and restores defaults', () async {
      await bridge.requestAccessibilityPermission();
      bridge.isAccessibilityEnabled = false;

      bridge.reset();

      expect(bridge.requestAccessibilityCalls, 0);
      expect(bridge.isAccessibilityEnabled, isTrue);
      expect(bridge.syncRulesCalls, isEmpty);
    });
  });
}
