import 'package:block_reels/features/statistics/domain/models/block_record.dart';
import 'package:block_reels/features/statistics/domain/models/stats_timeframe.dart';
import 'package:block_reels/features/statistics/domain/services/statistics_analytics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BlockRecord record(String id, DateTime timestamp, {int saved = 60}) {
    return BlockRecord(
      id: id,
      packageName: 'com.instagram.android',
      appType: 'INSTAGRAM',
      timestamp: timestamp,
      estimatedTimeSavedSeconds: saved,
    );
  }

  test('this week is a Monday-to-Sunday calendar week', () {
    final now = DateTime(2026, 8, 19, 12); // Wednesday
    final records = [
      record('previous_sunday', DateTime(2026, 8, 16, 23, 59)),
      record('monday_start', DateTime(2026, 8, 17)),
      record('wednesday', DateTime(2026, 8, 19, 10)),
      record('sunday_end', DateTime(2026, 8, 23, 23, 59)),
      record('next_monday', DateTime(2026, 8, 24)),
    ];

    final summary = StatisticsAnalyticsEngine.compute(
      records: records,
      timeframe: StatsTimeframe.thisWeek,
      now: now,
    );

    expect(summary.totalBlocks, 3);
  });

  test('saved minutes use floor rather than nearest-minute rounding', () {
    final summary = StatisticsAnalyticsEngine.compute(
      records: [record('almost_a_minute', DateTime(2026, 8, 19), saved: 59)],
      timeframe: StatsTimeframe.today,
      now: DateTime(2026, 8, 19, 12),
    );

    expect(summary.totalTimeSavedMinutes, 0);
  });

  test('empty periods have no peak hour or inferred focus score', () {
    final summary = StatisticsAnalyticsEngine.compute(
      records: const [],
      timeframe: StatsTimeframe.today,
      now: DateTime(2026, 10, 28),
    );

    expect(summary.totalBlocks, 0);
    expect(summary.peakHour, isNull);
    expect(summary.focusScore, isNull);
  });

  test('day and month boundaries exclude adjacent recorded events', () {
    final now = DateTime(2026, 11, 1, 12);
    final records = [
      record('october', DateTime(2026, 10, 31, 23, 59), saved: 45),
      record('november', DateTime(2026, 11, 1), saved: 90),
      record('following_day', DateTime(2026, 11, 2), saved: 45),
    ];

    final today = StatisticsAnalyticsEngine.compute(
      records: records,
      timeframe: StatsTimeframe.today,
      now: now,
    );
    final month = StatisticsAnalyticsEngine.compute(
      records: records,
      timeframe: StatsTimeframe.thisMonth,
      now: now,
    );
    expect(today.totalBlocks, 1);
    expect(today.totalTimeSavedMinutes, 1);
    expect(today.peakHour, 0);
    expect(today.focusScore, isNull);
    expect(month.totalBlocks, 2);
    expect(month.totalTimeSavedMinutes, 2);
  });

  test('saved time sums each recorded estimate before rounding', () {
    final now = DateTime(2026, 10, 28, 10);
    final summary = StatisticsAnalyticsEngine.compute(
      records: [
        record('one', now, saved: 45),
        record('two', now, saved: 45),
      ],
      timeframe: StatsTimeframe.today,
      now: now,
    );
    expect(summary.totalTimeSavedMinutes, 1);
    expect(summary.blocksByApp['Instagram'], 2);
    expect(summary.appPercentages['Instagram'], 100);
  });
}
