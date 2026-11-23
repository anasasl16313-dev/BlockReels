import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:block_reels/core/models/schedule_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleModel Model & Midnight-Crossing Logic Tests', () {
    test('Same-day schedule evaluates active interval correctly', () {
      final workSchedule = ScheduleModel(
        id: 'work_hours',
        name: 'Work Hours',
        daysOfWeek: [1, 2, 3, 4, 5], // Monday - Friday
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
      );

      // Wednesday (weekday 3) at 10:30 AM -> Active
      final wednesdayActive =
          DateTime(2026, 8, 19, 10, 30); // 2026-08-19 is Wednesday
      expect(workSchedule.isCurrentlyActive(wednesdayActive), isTrue);

      // Wednesday at 08:59 AM -> Inactive
      final wednesdayBefore = DateTime(2026, 8, 19, 8, 59);
      expect(workSchedule.isCurrentlyActive(wednesdayBefore), isFalse);

      // Wednesday at 17:01 PM -> Inactive
      final wednesdayAfter = DateTime(2026, 8, 19, 17, 1);
      expect(workSchedule.isCurrentlyActive(wednesdayAfter), isFalse);

      // Saturday (weekday 6) at 11:00 AM -> Inactive (not in daysOfWeek)
      final saturday = DateTime(2026, 8, 22, 11, 0); // 2026-08-22 is Saturday
      expect(workSchedule.isCurrentlyActive(saturday), isFalse);
    });

    test(
        'Midnight-crossing schedule evaluates late night and morning intervals correctly',
        () {
      // Bedtime schedule on Monday only (1 = Monday): 22:00 -> 06:00
      final bedtimeMondayOnly = ScheduleModel(
        id: 'bedtime_mon',
        name: 'Monday Bedtime',
        daysOfWeek: [1], // Monday only
        startHour: 22,
        startMinute: 0,
        endHour: 6,
        endMinute: 0,
      );

      // Monday night 23:30 (Monday is weekday 1) -> Active
      final mondayNight = DateTime(2026, 8, 17, 23, 30); // 2026-08-17 is Monday
      expect(bedtimeMondayOnly.isCurrentlyActive(mondayNight), isTrue);

      // Tuesday early morning 03:00 (Tuesday is weekday 2) -> Active (carries over from active Monday)
      final tuesdayMorning =
          DateTime(2026, 8, 18, 3, 0); // 2026-08-18 is Tuesday
      expect(bedtimeMondayOnly.isCurrentlyActive(tuesdayMorning), isTrue);

      // Tuesday morning 06:01 -> Inactive (ended at 06:00)
      final tuesdayDay = DateTime(2026, 8, 18, 6, 1);
      expect(bedtimeMondayOnly.isCurrentlyActive(tuesdayDay), isFalse);

      // Wednesday early morning 03:00 -> Inactive (Tuesday was not in daysOfWeek)
      final wednesdayMorning = DateTime(2026, 8, 19, 3, 0);
      expect(bedtimeMondayOnly.isCurrentlyActive(wednesdayMorning), isFalse);
    });

    test(
        'Midnight-crossing schedule spanning Sunday to Monday handles week rollover',
        () {
      // Schedule active Sunday nights: 22:00 -> 05:00
      final sundayNightSchedule = ScheduleModel(
        id: 'sunday_night',
        name: 'Sunday Night Focus',
        daysOfWeek: [7], // 7 = Sunday
        startHour: 22,
        startMinute: 0,
        endHour: 5,
        endMinute: 0,
      );

      // Sunday night 23:00 -> Active
      final sundayNight = DateTime(2026, 8, 16, 23, 0); // 2026-08-16 is Sunday
      expect(sundayNightSchedule.isCurrentlyActive(sundayNight), isTrue);

      // Monday morning 02:30 -> Active (Sunday carried over across ISO week rollover)
      final mondayEarly =
          DateTime(2026, 8, 17, 2, 30); // 2026-08-17 is Monday (weekday 1)
      expect(sundayNightSchedule.isCurrentlyActive(mondayEarly), isTrue);

      // Monday morning 05:30 -> Inactive
      final mondayAfter = DateTime(2026, 8, 17, 5, 30);
      expect(sundayNightSchedule.isCurrentlyActive(mondayAfter), isFalse);
    });

    test('zero-duration schedule is never active', () {
      final zeroDuration = ScheduleModel(
        id: 'zero_duration',
        name: 'Zero Duration',
        daysOfWeek: [7],
        startHour: 10,
        startMinute: 0,
        endHour: 10,
        endMinute: 0,
      );

      final sundayMidday = DateTime(2026, 8, 16, 14, 0);
      expect(zeroDuration.isCurrentlyActive(sundayMidday), isFalse);

      final mondayMidday = DateTime(2026, 8, 17, 14, 0);
      expect(zeroDuration.isCurrentlyActive(mondayMidday), isFalse);
    });

    test('Inactive schedule returns false unconditionally', () {
      final inactive = ScheduleModel(
        id: 'off',
        name: 'Disabled',
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        startHour: 0,
        startMinute: 0,
        endHour: 23,
        endMinute: 59,
        isActive: false,
      );

      expect(inactive.isCurrentlyActive(DateTime.now()), isFalse);
    });

    test('appliesToPackage matches empty target list or specific packages', () {
      final universal = ScheduleModel(
        id: 'all',
        name: 'All Apps',
        daysOfWeek: [1],
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        targetPackageNames: [],
      );
      expect(universal.appliesToPackage('com.instagram.android'), isTrue);
      expect(universal.appliesToPackage('com.google.android.youtube'), isTrue);

      final specific = ScheduleModel(
        id: 'ig_only',
        name: 'IG Only',
        daysOfWeek: [1],
        startHour: 9,
        startMinute: 0,
        endHour: 17,
        endMinute: 0,
        targetPackageNames: ['com.instagram.android'],
      );
      expect(specific.appliesToPackage('com.instagram.android'), isTrue);
      expect(specific.appliesToPackage('com.google.android.youtube'), isFalse);
    });

    test('formatting helpers produce clean output', () {
      final schedule = ScheduleModel(
        id: 'test',
        name: 'Test',
        daysOfWeek: [1, 2, 3, 4, 5],
        startHour: 8,
        startMinute: 5,
        endHour: 18,
        endMinute: 30,
      );

      expect(schedule.formattedTimeRange, '08:05 - 18:30');
      expect(schedule.formattedDays, 'Weekdays');

      final weekend = schedule.copyWith(daysOfWeek: [6, 7]);
      expect(weekend.formattedDays, 'Weekends');

      final everyDay = schedule.copyWith(daysOfWeek: [1, 2, 3, 4, 5, 6, 7]);
      expect(everyDay.formattedDays, 'Every day');

      final customDays = schedule.copyWith(daysOfWeek: [1, 3, 5]);
      expect(customDays.formattedDays, 'Mon, Wed, Fri');
    });

    test('JSON serialization roundtrip maintains fields', () {
      final schedule = ScheduleModel(
        id: 'deep_focus',
        name: 'Deep Focus',
        daysOfWeek: [1, 3, 5],
        startHour: 13,
        startMinute: 30,
        endHour: 16,
        endMinute: 45,
        targetPackageNames: [
          'com.instagram.android',
          'com.zhiliaoapp.musically'
        ],
        isActive: true,
        overrideMode: InterventionMode.strictBlock,
      );

      final json = schedule.toJson();
      final restored = ScheduleModel.fromJson(json);

      expect(restored.id, schedule.id);
      expect(restored.name, schedule.name);
      expect(restored.daysOfWeek, schedule.daysOfWeek);
      expect(restored.startHour, schedule.startHour);
      expect(restored.startMinute, schedule.startMinute);
      expect(restored.endHour, schedule.endHour);
      expect(restored.endMinute, schedule.endMinute);
      expect(restored.targetPackageNames, schedule.targetPackageNames);
      expect(restored.isActive, schedule.isActive);
      expect(restored.overrideMode, schedule.overrideMode);
    });
    test('quick boost is a one-shot epoch window and ignores weekdays', () {
      final startedAt = DateTime(2026, 8, 19, 10, 0); // Wednesday
      final boost = ScheduleModel(
        id: 'quick_boost_${startedAt.millisecondsSinceEpoch}',
        name: 'Quick Boost',
        daysOfWeek: [1], // Monday only, deliberately ignored for one-shot
        startHour: 10,
        startMinute: 0,
        endHour: 10,
        endMinute: 25,
      );

      expect(
        boost.isCurrentlyActive(startedAt.add(const Duration(minutes: 5))),
        isTrue,
      );
      expect(boost.isCurrentlyActive(startedAt), isTrue);
      expect(
        boost.isCurrentlyActive(startedAt.subtract(const Duration(minutes: 1))),
        isFalse,
      );
      expect(
        boost.isCurrentlyActive(startedAt.add(const Duration(minutes: 25))),
        isFalse,
      );
      expect(
        boost.isCurrentlyActive(startedAt.add(const Duration(days: 7))),
        isFalse,
      );
    });
  });
}
