/// Aggregated metrics, KPI analytics, and platform breakdowns.
class StatisticsSummary {
  final int totalBlocks;
  final int totalTimeSavedMinutes;
  final int totalTimeSavedSeconds;
  final Map<String, int> blocksByApp;
  final Map<String, double> appPercentages;
  final List<int> hourlyBins; // 24 hour slots 0..23
  final int? peakHour;

  /// Unavailable until override outcomes are recorded reliably.
  final int? focusScore;

  const StatisticsSummary({
    required this.totalBlocks,
    required this.totalTimeSavedMinutes,
    this.totalTimeSavedSeconds = 0,
    required this.blocksByApp,
    required this.appPercentages,
    required this.hourlyBins,
    required this.peakHour,
    required this.focusScore,
  });

  factory StatisticsSummary.empty() => StatisticsSummary(
        totalBlocks: 0,
        totalTimeSavedMinutes: 0,
        totalTimeSavedSeconds: 0,
        blocksByApp: const {},
        appPercentages: const {},
        hourlyBins: List.filled(24, 0),
        peakHour: null,
        focusScore: null,
      );

  StatisticsSummary copyWith({
    int? totalBlocks,
    int? totalTimeSavedMinutes,
    int? totalTimeSavedSeconds,
    Map<String, int>? blocksByApp,
    Map<String, double>? appPercentages,
    List<int>? hourlyBins,
    int? peakHour,
    int? focusScore,
  }) {
    return StatisticsSummary(
      totalBlocks: totalBlocks ?? this.totalBlocks,
      totalTimeSavedMinutes:
          totalTimeSavedMinutes ?? this.totalTimeSavedMinutes,
      totalTimeSavedSeconds:
          totalTimeSavedSeconds ?? this.totalTimeSavedSeconds,
      blocksByApp: blocksByApp ?? this.blocksByApp,
      appPercentages: appPercentages ?? this.appPercentages,
      hourlyBins: hourlyBins ?? this.hourlyBins,
      peakHour: peakHour ?? this.peakHour,
      focusScore: focusScore ?? this.focusScore,
    );
  }

  @override
  String toString() =>
      'StatisticsSummary(blocks: $totalBlocks, saved: ${totalTimeSavedMinutes}m, score: $focusScore%, peakHour: $peakHour)';
}
