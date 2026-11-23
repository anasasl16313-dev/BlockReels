import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/platform_channel/dtos/schedule_dto.dart';
import 'package:block_reels/core/platform_channel/dtos/platform_event.dart';
import 'package:block_reels/core/platform_channel/method_channel_platform_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.blockreels.app/platform');
  late List<MethodCall> calls;
  late MethodChannelPlatformBridge bridge;

  setUp(() {
    calls = [];
    bridge = MethodChannelPlatformBridge();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isAccessibilityServiceEnabled':
        case 'isBatteryOptimizationIgnored':
        case 'syncRules':
        case 'syncSchedules':
        case 'syncAppToggles':
        case 'syncInterventionConfig':
        case 'updateSettings':
        case 'grantTemporaryAllowance':
        case 'acknowledgeBlockEvents':
          return true;
        case 'readPendingBlockEvents':
          return [
            {
              'eventId': 'persisted-event',
              'timestamp': 12345,
              'packageName': 'com.instagram.android',
              'appType': 'INSTAGRAM',
              'interventionMode': 'AUTO_BACK',
              'detectionReason': 'PRIMARY_RESOURCE_ID',
            },
          ];
        case 'getInstalledApps':
          return [
            {
              'packageName': 'com.instagram.android',
              'appName': 'Instagram',
              'isInstalled': false,
            },
          ];
        case 'getRealtimeMetrics':
          return {
            'totalBlockedToday': 4,
            'byApp': {'com.instagram.android': 4},
          };
        default:
          return false;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('permission and sync calls use the production method channel', () async {
    expect(await bridge.isAccessibilityServiceEnabled(), isTrue);
    expect(await bridge.isBatteryOptimizationDisabled(), isTrue);

    final rules = [
      RuleModel(
        id: 'ig',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
      ),
    ];
    expect(await bridge.syncRules(rules), isTrue);
    expect(
      await bridge.syncAppToggles({'com.instagram.android': true}),
      isTrue,
    );
    expect(
      await bridge.syncSchedules([
        const ScheduleDto(
          id: 'work',
          title: 'Work',
          daysOfWeek: [1, 2, 3, 4, 5],
          startHour: 9,
          startMinute: 0,
          endHour: 17,
          endMinute: 0,
        ),
      ]),
      isTrue,
    );
    final settings = AppSettings(
      isMasterEnabled: false,
      pinLockEnabled: true,
      pinHash: 'unit-test-hash',
      pinSalt: 'unit-test-salt',
    );
    expect(await bridge.updateSettings(settings), isTrue);
    expect(calls.singleWhere((call) => call.method == 'updateSettings').arguments,
        {'isMasterEnabled': false});

    final ruleCall = calls.firstWhere((call) => call.method == 'syncRules');
    expect(ruleCall.arguments, isA<Map>());
    expect((ruleCall.arguments as Map)['rules'], hasLength(1));

    final scheduleCall = calls.firstWhere(
      (call) => call.method == 'syncSchedules',
    );
    expect((scheduleCall.arguments as Map)['schedules'], hasLength(1));
  });

  test('temporary allowance serializes package and duration', () async {
    expect(
      await bridge.grantTemporaryAllowance(
        'com.instagram.android',
        durationSeconds: 90,
      ),
      isTrue,
    );

    final call = calls.singleWhere(
      (call) => call.method == 'grantTemporaryAllowance',
    );
    expect(call.arguments['packageName'], 'com.instagram.android');
    expect(call.arguments['durationSeconds'], 90);
  });

  test('installed apps and realtime metrics decode native maps', () async {
    final apps = await bridge.getInstalledApps();
    expect(apps.single.packageName, 'com.instagram.android');
    expect(apps.single.isInstalled, isFalse);
    expect(apps.single.copyWith(isInstalled: true).isInstalled, isTrue);
    expect(apps.single.toMap()['isInstalled'], isFalse);

    final metrics = await bridge.getRealtimeMetrics();
    expect(metrics.totalBlockedToday, 4);
    expect(metrics.byApp['com.instagram.android'], 4);
  });

  test('pending event bridge calls preserve IDs and bound reads', () async {
    final events = await bridge.readPendingBlockEvents(limit: 500);
    expect(events.single.eventId, 'persisted-event');
    expect(
      BlockEvent.fromJson(events.single.toJson()).eventId,
      'persisted-event',
    );
    expect(calls.last.arguments['limit'], 100);
    expect(await bridge.acknowledgeBlockEvents(['persisted-event']), isTrue);
    expect(calls.last.method, 'acknowledgeBlockEvents');
    expect(calls.last.arguments['ids'], ['persisted-event']);
  });
}
