import 'package:block_reels/core/platform_channel/dtos/intervention_config_dto.dart';
import 'package:block_reels/core/platform_channel/dtos/platform_event.dart';
import 'package:block_reels/core/platform_channel/dtos/realtime_metrics_dto.dart';
import 'package:block_reels/core/platform_channel/dtos/schedule_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform Bridge DTOs & Events Tests', () {
    test('InterventionConfigDto JSON serialization roundtrip', () {
      const config = InterventionConfigDto(
        defaultMode: 'STRICT_BLOCK',
        holdDurationSeconds: 12,
        customMessage: 'Stay on task',
        pinProtected: true,
        soundEnabled: false,
        hapticsEnabled: true,
      );

      final json = config.toJson();
      final restored = InterventionConfigDto.fromJson(json);

      expect(restored.defaultMode, config.defaultMode);
      expect(restored.holdDurationSeconds, config.holdDurationSeconds);
      expect(restored.customMessage, config.customMessage);
      expect(restored.pinProtected, config.pinProtected);
      expect(restored.soundEnabled, config.soundEnabled);
      expect(restored.hapticsEnabled, config.hapticsEnabled);
    });

    test('ScheduleDto JSON serialization roundtrip', () {
      const schedule = ScheduleDto(
        id: 'sch_work',
        title: 'Work Hours',
        isActive: true,
        daysOfWeek: [1, 2, 3, 4, 5],
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        enabledPackages: ['com.instagram.android'],
      );

      final json = schedule.toJson();
      final restored = ScheduleDto.fromJson(json);

      expect(restored.id, schedule.id);
      expect(restored.title, schedule.title);
      expect(restored.isActive, schedule.isActive);
      expect(restored.daysOfWeek, schedule.daysOfWeek);
      expect(restored.startHour, schedule.startHour);
      expect(restored.startMinute, schedule.startMinute);
      expect(restored.endHour, schedule.endHour);
      expect(restored.endMinute, schedule.endMinute);
      expect(restored.enabledPackages, schedule.enabledPackages);
    });

    test('RealtimeMetricsDto JSON serialization roundtrip', () {
      const metrics = RealtimeMetricsDto(
        totalBlockedToday: 42,
        byApp: {'Instagram': 25, 'YouTube Shorts': 17},
        lastBlockedPackage: 'com.instagram.android',
        lastBlockedTimestamp: 1723730000000,
        serviceUptimeMs: 3600000,
      );

      final json = metrics.toJson();
      final restored = RealtimeMetricsDto.fromJson(json);

      expect(restored.totalBlockedToday, 42);
      expect(restored.byApp['Instagram'], 25);
      expect(restored.byApp['YouTube Shorts'], 17);
      expect(restored.lastBlockedPackage, 'com.instagram.android');
      expect(restored.lastBlockedTimestamp, 1723730000000);
      expect(restored.serviceUptimeMs, 3600000);
    });

    test('PlatformEvent factory parses discriminators accurately', () {
      final blockJson = {
        'eventType': 'REEL_BLOCKED',
        'timestamp': 1723731000000,
        'packageName': 'com.zhiliaoapp.musically',
        'appType': 'TikTok',
        'interventionMode': 'MINDFUL_PAUSE',
        'detectionReason': 'SURGICAL_HEURISTIC',
      };
      final blockEvent = PlatformEvent.fromJson(blockJson);
      expect(blockEvent, isA<BlockEvent>());
      final b = blockEvent as BlockEvent;
      expect(b.packageName, 'com.zhiliaoapp.musically');
      expect(b.appType, 'TikTok');
      expect(b.interventionMode, 'MINDFUL_PAUSE');

      final serviceJson = {
        'eventType': 'SERVICE_STATE_CHANGED',
        'timestamp': 1723731000000,
        'isEnabled': true,
      };
      final serviceEvent = PlatformEvent.fromJson(serviceJson);
      expect(serviceEvent, isA<ServiceStatusEvent>());
      expect((serviceEvent as ServiceStatusEvent).isEnabled, isTrue);

      final batteryJson = {
        'eventType': 'BATTERY_OPT_CHANGED',
        'timestamp': 1723731000000,
        'isIgnored': true,
      };
      final batteryEvent = PlatformEvent.fromJson(batteryJson);
      expect(batteryEvent, isA<BatteryOptEvent>());
      expect((batteryEvent as BatteryOptEvent).isIgnored, isTrue);

      final genericJson = {
        'eventType': 'CUSTOM_NOTIFICATION',
        'timestamp': 1723731000000,
        'extraKey': 'extraValue',
      };
      final genericEvent = PlatformEvent.fromJson(genericJson);
      expect(genericEvent, isA<GenericPlatformEvent>());
      expect((genericEvent as GenericPlatformEvent).eventType,
          'CUSTOM_NOTIFICATION');
    });
  });
}
