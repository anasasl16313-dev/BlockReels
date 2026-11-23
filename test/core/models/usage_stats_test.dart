import 'package:block_reels/core/models/usage_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UsageStats Model Tests', () {
    test('empty factory creates zero-initialized stats', () {
      final stats = UsageStats.empty();

      expect(stats.totalBlockedLifetime, 0);
      expect(stats.totalBlockedToday, 0);
      expect(stats.totalBlockedThisWeek, 0);
      expect(stats.totalTimeSavedMinutes, 0);
      expect(stats.currentStreakDays, 0);
      expect(stats.bestStreakDays, 0);
      expect(stats.blocksByApp, isEmpty);
      expect(stats.blocksByHour, isEmpty);
      expect(stats.dailyTrends, isEmpty);
    });

    test('copyWith updates specified analytics fields', () {
      final stats = UsageStats.empty();
      final updated = stats.copyWith(
        totalBlockedLifetime: 150,
        totalBlockedToday: 12,
        totalTimeSavedMinutes: 110,
        currentStreakDays: 5,
        blocksByApp: {'Instagram': 80, 'YouTube Shorts': 70},
      );

      expect(updated.totalBlockedLifetime, 150);
      expect(updated.totalBlockedToday, 12);
      expect(updated.totalTimeSavedMinutes, 110);
      expect(updated.currentStreakDays, 5);
      expect(updated.blocksByApp['Instagram'], 80);
      expect(updated.blocksByApp['YouTube Shorts'], 70);
    });

    test('JSON serialization roundtrip maintains maps and trend lists', () {
      final trend1 = DailyTrendPoint(
        date: DateTime(2026, 8, 14),
        count: 10,
        timeSavedSeconds: 450,
      );
      final trend2 = DailyTrendPoint(
        date: DateTime(2026, 8, 15),
        count: 15,
        timeSavedSeconds: 675,
      );

      final stats = UsageStats(
        totalBlockedLifetime: 25,
        totalBlockedToday: 15,
        totalBlockedThisWeek: 25,
        totalTimeSavedMinutes: 18,
        currentStreakDays: 2,
        bestStreakDays: 4,
        blocksByApp: {'Instagram': 15, 'TikTok': 10},
        blocksByHour: {9: 5, 14: 10, 21: 10},
        dailyTrends: [trend1, trend2],
      );

      final json = stats.toJson();
      final restored = UsageStats.fromJson(json);

      expect(restored.totalBlockedLifetime, stats.totalBlockedLifetime);
      expect(restored.totalBlockedToday, stats.totalBlockedToday);
      expect(restored.totalBlockedThisWeek, stats.totalBlockedThisWeek);
      expect(restored.totalTimeSavedMinutes, stats.totalTimeSavedMinutes);
      expect(restored.currentStreakDays, stats.currentStreakDays);
      expect(restored.bestStreakDays, stats.bestStreakDays);
      expect(restored.blocksByApp['Instagram'], 15);
      expect(restored.blocksByApp['TikTok'], 10);
      expect(restored.blocksByHour[9], 5);
      expect(restored.blocksByHour[14], 10);
      expect(restored.blocksByHour[21], 10);
      expect(restored.dailyTrends.length, 2);
      expect(restored.dailyTrends[0].count, 10);
      expect(restored.dailyTrends[1].timeSavedSeconds, 675);
    });
  });
}
