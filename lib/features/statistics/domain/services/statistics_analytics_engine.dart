import '../models/block_record.dart';
import '../models/statistics_summary.dart';
import '../models/stats_timeframe.dart';

/// Analytics for recorded interceptions in the selected calendar period.
class StatisticsAnalyticsEngine {
  /// Computes a [StatisticsSummary] from [records] according to [timeframe] relative to [now].
  static StatisticsSummary compute({
    required List<BlockRecord> records,
    required StatsTimeframe timeframe,
    required DateTime now,
  }) {
    // 1. Filter by timeframe
    final filtered = records.where((r) {
      switch (timeframe) {
        case StatsTimeframe.today:
          return r.timestamp.year == now.year &&
              r.timestamp.month == now.month &&
              r.timestamp.day == now.day;
        case StatsTimeframe.thisWeek:
          final startOfWeek =
              DateTime(now.year, now.month, now.day - now.weekday + 1);
          final endOfWeek =
              DateTime(now.year, now.month, now.day - now.weekday + 8);
          return !r.timestamp.isBefore(startOfWeek) &&
              r.timestamp.isBefore(endOfWeek);
        case StatsTimeframe.thisMonth:
          return r.timestamp.year == now.year && r.timestamp.month == now.month;
        case StatsTimeframe.allTime:
          return true;
      }
    }).toList();

    if (filtered.isEmpty) {
      return StatisticsSummary.empty();
    }

    // 2. Aggregations
    int totalTimeSavedSecs = 0;
    final Map<String, int> byApp = {};
    final List<int> bins = List.filled(24, 0);

    for (final r in filtered) {
      totalTimeSavedSecs += r.estimatedTimeSavedSeconds;
      final appName = _displayAppName(r.appType);
      byApp[appName] = (byApp[appName] ?? 0) + 1;
      if (r.timestamp.hour >= 0 && r.timestamp.hour < 24) {
        bins[r.timestamp.hour]++;
      }
    }

    // 3. Percentages
    final total = filtered.length;
    final Map<String, double> percentages = {};
    byApp.forEach((app, count) {
      percentages[app] = (count / total) * 100.0;
    });

    // 4. Peak Hour
    int maxHour = 0;
    int maxCount = 0;
    for (int h = 0; h < 24; h++) {
      if (bins[h] > maxCount) {
        maxCount = bins[h];
        maxHour = h;
      }
    }

    return StatisticsSummary(
      totalBlocks: total,
      totalTimeSavedMinutes: totalTimeSavedSecs ~/ 60,
      totalTimeSavedSeconds: totalTimeSavedSecs,
      blocksByApp: byApp,
      appPercentages: percentages,
      hourlyBins: bins,
      peakHour: maxHour,
      // Native block events do not report eventual hold/allowance outcomes.
      focusScore: null,
    );
  }

  static String _displayAppName(String appType) {
    switch (appType.toUpperCase()) {
      case 'INSTAGRAM':
        return 'Instagram';
      case 'YOUTUBE':
      case 'YOUTUBE SHORTS':
        return 'YouTube';
      case 'FACEBOOK':
      case 'FACEBOOK REELS':
        return 'Facebook';
      case 'TIKTOK':
      case 'DOUYIN':
        return 'TikTok';
      default:
        return appType.trim().isEmpty ? 'Unknown app' : appType;
    }
  }
}
