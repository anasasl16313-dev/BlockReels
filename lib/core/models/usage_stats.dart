/// Represents a single historical day's aggregated metrics for trend charts.
class DailyTrendPoint {
  final DateTime date;
  final int count;
  final int timeSavedSeconds;

  const DailyTrendPoint({
    required this.date,
    required this.count,
    required this.timeSavedSeconds,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'count': count,
        'timeSavedSeconds': timeSavedSeconds,
      };

  factory DailyTrendPoint.fromJson(Map<String, dynamic> json) =>
      DailyTrendPoint(
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
            : DateTime.now(),
        count: json['count'] as int? ?? 0,
        timeSavedSeconds: json['timeSavedSeconds'] as int? ?? 0,
      );
}

/// Represents real-time computed offline analytics across intercepted video feeds.
class UsageStats {
  final int totalBlockedLifetime;
  final int totalBlockedToday;
  final int totalBlockedThisWeek;
  final int totalTimeSavedMinutes;
  final int totalTimeSavedSeconds;
  final int currentStreakDays;
  final int bestStreakDays;
  final Map<String, int> blocksByApp;
  final Map<int, int> blocksByHour; // 0..23 -> count
  final List<DailyTrendPoint> dailyTrends;

  const UsageStats({
    required this.totalBlockedLifetime,
    required this.totalBlockedToday,
    required this.totalBlockedThisWeek,
    required this.totalTimeSavedMinutes,
    this.totalTimeSavedSeconds = 0,
    required this.currentStreakDays,
    required this.bestStreakDays,
    this.blocksByApp = const {},
    this.blocksByHour = const {},
    this.dailyTrends = const [],
  });

  factory UsageStats.empty() => const UsageStats(
        totalBlockedLifetime: 0,
        totalBlockedToday: 0,
        totalBlockedThisWeek: 0,
        totalTimeSavedMinutes: 0,
        totalTimeSavedSeconds: 0,
        currentStreakDays: 0,
        bestStreakDays: 0,
        blocksByApp: {},
        blocksByHour: {},
        dailyTrends: [],
      );

  UsageStats copyWith({
    int? totalBlockedLifetime,
    int? totalBlockedToday,
    int? totalBlockedThisWeek,
    int? totalTimeSavedMinutes,
    int? totalTimeSavedSeconds,
    int? currentStreakDays,
    int? bestStreakDays,
    Map<String, int>? blocksByApp,
    Map<int, int>? blocksByHour,
    List<DailyTrendPoint>? dailyTrends,
  }) {
    return UsageStats(
      totalBlockedLifetime: totalBlockedLifetime ?? this.totalBlockedLifetime,
      totalBlockedToday: totalBlockedToday ?? this.totalBlockedToday,
      totalBlockedThisWeek: totalBlockedThisWeek ?? this.totalBlockedThisWeek,
      totalTimeSavedMinutes:
          totalTimeSavedMinutes ?? this.totalTimeSavedMinutes,
      totalTimeSavedSeconds:
          totalTimeSavedSeconds ?? this.totalTimeSavedSeconds,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      bestStreakDays: bestStreakDays ?? this.bestStreakDays,
      blocksByApp: blocksByApp ?? Map.from(this.blocksByApp),
      blocksByHour: blocksByHour ?? Map.from(this.blocksByHour),
      dailyTrends: dailyTrends ?? List.from(this.dailyTrends),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalBlockedLifetime': totalBlockedLifetime,
      'totalBlockedToday': totalBlockedToday,
      'totalBlockedThisWeek': totalBlockedThisWeek,
      'totalTimeSavedMinutes': totalTimeSavedMinutes,
      'totalTimeSavedSeconds': totalTimeSavedSeconds,
      'currentStreakDays': currentStreakDays,
      'bestStreakDays': bestStreakDays,
      'blocksByApp': blocksByApp,
      'blocksByHour': blocksByHour.map((k, v) => MapEntry(k.toString(), v)),
      'dailyTrends': dailyTrends.map((e) => e.toJson()).toList(),
    };
  }

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    final rawByHour = json['blocksByHour'] as Map<String, dynamic>?;
    final Map<int, int> parsedByHour = {};
    if (rawByHour != null) {
      rawByHour.forEach((k, v) {
        final keyInt = int.tryParse(k);
        if (keyInt != null && v is int) {
          parsedByHour[keyInt] = v;
        }
      });
    }

    final rawByApp = json['blocksByApp'] as Map<String, dynamic>?;
    final Map<String, int> parsedByApp = {};
    if (rawByApp != null) {
      rawByApp.forEach((k, v) {
        if (v is int) parsedByApp[k] = v;
      });
    }

    final rawTrends = json['dailyTrends'] as List<dynamic>?;
    final List<DailyTrendPoint> parsedTrends = rawTrends != null
        ? rawTrends
            .map((e) => DailyTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList()
        : const [];

    return UsageStats(
      totalBlockedLifetime: json['totalBlockedLifetime'] as int? ?? 0,
      totalBlockedToday: json['totalBlockedToday'] as int? ?? 0,
      totalBlockedThisWeek: json['totalBlockedThisWeek'] as int? ?? 0,
      totalTimeSavedMinutes: json['totalTimeSavedMinutes'] as int? ?? 0,
      totalTimeSavedSeconds: json['totalTimeSavedSeconds'] as int? ??
          (json['totalTimeSavedMinutes'] as int? ?? 0) * 60,
      currentStreakDays: json['currentStreakDays'] as int? ?? 0,
      bestStreakDays: json['bestStreakDays'] as int? ?? 0,
      blocksByApp: parsedByApp,
      blocksByHour: parsedByHour,
      dailyTrends: parsedTrends,
    );
  }
}
