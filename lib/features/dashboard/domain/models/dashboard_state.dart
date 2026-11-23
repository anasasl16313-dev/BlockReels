import '../../../../core/models/history_log.dart';
import '../../../../core/models/metrics_load_state.dart';
import 'protection_status.dart';

/// Immutable representation of the dashboard live status, KPI metrics, active toggles, and streaks.
class DashboardState {
  final ProtectionStatus protectionStatus;
  final bool isMasterEnabled;
  final bool isAccessibilityServiceActive;
  final bool isBatteryOptimizationIgnored;
  final int totalBlockedToday;
  final int totalTimeSavedMinutes;
  final int totalTimeSavedSeconds;
  final int totalRecordedBlocks;
  final MetricsLoadState metricsLoadState;
  final int currentStreakDays;
  final List<bool> weeklyStreakDots; // 7 days: Mon-Sun
  final Map<String, bool> activeToggles;
  final List<HistoryLog> recentEvents;
  final String? activeBoostSessionName;
  final DateTime? activeBoostEndsAt;
  final int? activeBoostRemainingSeconds;

  const DashboardState({
    this.protectionStatus = const ProtectionStatus.verifying(),
    this.isMasterEnabled = true,
    this.isAccessibilityServiceActive = false,
    this.isBatteryOptimizationIgnored = false,
    this.totalBlockedToday = 0,
    this.totalTimeSavedMinutes = 0,
    this.totalTimeSavedSeconds = 0,
    this.totalRecordedBlocks = 0,
    this.metricsLoadState = MetricsLoadState.loading,
    this.currentStreakDays = 0,
    this.weeklyStreakDots = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false
    ],
    this.activeToggles = const {
      'com.instagram.android': true,
      'com.google.android.youtube': true,
      'com.facebook.katana': false,
      'com.zhiliaoapp.musically': true,
    },
    this.recentEvents = const [],
    this.activeBoostSessionName,
    this.activeBoostEndsAt,
    this.activeBoostRemainingSeconds,
  });

  DashboardState copyWith({
    ProtectionStatus? protectionStatus,
    bool? isMasterEnabled,
    bool? isAccessibilityServiceActive,
    bool? isBatteryOptimizationIgnored,
    int? totalBlockedToday,
    int? totalTimeSavedMinutes,
    int? totalTimeSavedSeconds,
    int? totalRecordedBlocks,
    MetricsLoadState? metricsLoadState,
    int? currentStreakDays,
    List<bool>? weeklyStreakDots,
    Map<String, bool>? activeToggles,
    List<HistoryLog>? recentEvents,
    String? activeBoostSessionName,
    DateTime? activeBoostEndsAt,
    int? activeBoostRemainingSeconds,
    bool clearActiveBoost = false,
  }) {
    return DashboardState(
      protectionStatus: protectionStatus ?? this.protectionStatus,
      isMasterEnabled: isMasterEnabled ?? this.isMasterEnabled,
      isAccessibilityServiceActive:
          isAccessibilityServiceActive ?? this.isAccessibilityServiceActive,
      isBatteryOptimizationIgnored:
          isBatteryOptimizationIgnored ?? this.isBatteryOptimizationIgnored,
      totalBlockedToday: totalBlockedToday ?? this.totalBlockedToday,
      totalTimeSavedMinutes:
          totalTimeSavedMinutes ?? this.totalTimeSavedMinutes,
      totalTimeSavedSeconds:
          totalTimeSavedSeconds ?? this.totalTimeSavedSeconds,
      totalRecordedBlocks: totalRecordedBlocks ?? this.totalRecordedBlocks,
      metricsLoadState: metricsLoadState ?? this.metricsLoadState,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      weeklyStreakDots: weeklyStreakDots ?? this.weeklyStreakDots,
      activeToggles: activeToggles ?? this.activeToggles,
      recentEvents: recentEvents ?? this.recentEvents,
      activeBoostSessionName: clearActiveBoost
          ? null
          : (activeBoostSessionName ?? this.activeBoostSessionName),
      activeBoostEndsAt: clearActiveBoost
          ? null
          : (activeBoostEndsAt ?? this.activeBoostEndsAt),
      activeBoostRemainingSeconds: clearActiveBoost
          ? null
          : (activeBoostRemainingSeconds ?? this.activeBoostRemainingSeconds),
    );
  }
}
