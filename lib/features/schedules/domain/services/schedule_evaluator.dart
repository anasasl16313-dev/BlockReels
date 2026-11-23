import '../../../../core/models/quick_boost_window.dart';
import '../models/schedule_rule_model.dart';

/// Evaluator service providing static time-window and package matching algorithms.
class ScheduleEvaluator {
  /// Evaluates whether [schedule] is active at the provided [dateTime] (defaults to DateTime.now()).
  static bool isScheduleActiveNow(dynamic schedule, [DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();

    if (schedule is ScheduleRuleModel) {
      return schedule.isMatching(now);
    }

    if (schedule == null) return false;

    // Handle generic / dynamic schedule objects (e.g. ScheduleRule, ScheduleModel)
    try {
      final bool isActive = schedule.isActive as bool? ?? true;
      if (!isActive) return false;

      final int startHour = schedule.startHour as int;
      final int startMinute = schedule.startMinute as int;
      final int endHour = schedule.endHour as int;
      final int endMinute = schedule.endMinute as int;
      final String id = schedule.id as String? ?? '';

      if (id.startsWith(quickBoostIdPrefix)) {
        return isQuickBoostActive(
          id,
          now,
          startHour: startHour,
          startMinute: startMinute,
          endHour: endHour,
          endMinute: endMinute,
        );
      }

      final List<int> daysOfWeek =
          (schedule.daysOfWeek as List<dynamic>?)?.cast<int>() ?? const [];
      if (daysOfWeek.isEmpty) return false;

      final currentDay = now.weekday; // 1 = Mon .. 7 = Sun
      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = startHour * 60 + startMinute;
      final endMinutes = endHour * 60 + endMinute;

      // Degenerate zero-duration interval
      if (startMinutes == endMinutes) {
        return false;
      }

      if (startMinutes < endMinutes) {
        // Same-day window
        if (!daysOfWeek.contains(currentDay)) return false;
        return nowMinutes >= startMinutes && nowMinutes < endMinutes;
      } else {
        // Overnight midnight-crossing window
        final prevDay = currentDay == 1 ? 7 : currentDay - 1;
        final isEveningActive =
            daysOfWeek.contains(currentDay) && nowMinutes >= startMinutes;
        final isMorningActive =
            daysOfWeek.contains(prevDay) && nowMinutes < endMinutes;
        return isEveningActive || isMorningActive;
      }
    } catch (_) {
      return false;
    }
  }

  /// Evaluates whether a specific [packageName] is blocked by any schedule in [schedules].
  static bool isPackageBlocked(
    List<dynamic> schedules,
    String packageName, [
    DateTime? dateTime,
  ]) {
    final now = dateTime ?? DateTime.now();
    for (final schedule in schedules) {
      if (isScheduleActiveNow(schedule, now)) {
        List<String> packages = const [];
        if (schedule is ScheduleRuleModel) {
          packages = schedule.enabledPackageNames;
        } else {
          try {
            packages = (schedule.enabledPackageNames as List<dynamic>?)
                    ?.cast<String>() ??
                (schedule.enabledPackages as List<dynamic>?)?.cast<String>() ??
                (schedule.targetPackageNames as List<dynamic>?)
                    ?.cast<String>() ??
                const [];
          } catch (_) {
            packages = const [];
          }
        }

        if (packages.isEmpty || packages.contains(packageName)) {
          return true;
        }
      }
    }
    return false;
  }
}
