import 'intervention_mode.dart';
import 'quick_boost_window.dart';

/// Represents a scheduled active blocking interval for target applications.
class ScheduleModel {
  final String id;
  final String name;
  final List<int> daysOfWeek; // 1 = Monday, ..., 7 = Sunday (ISO-8601)
  final int startHour; // 0..23
  final int startMinute; // 0..59
  final int endHour; // 0..23
  final int endMinute; // 0..59
  final List<String>
      targetPackageNames; // Empty indicates applies to all target apps
  final bool isActive;
  final InterventionMode? overrideMode;

  ScheduleModel({
    required this.id,
    required this.name,
    required this.daysOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.targetPackageNames = const [],
    this.isActive = true,
    this.overrideMode,
  });

  /// Evaluates whether this schedule rule is actively in effect at the given time [now].
  /// Accurately evaluates both same-day intervals (e.g., 09:00 to 17:00) and
  /// midnight-crossing intervals (e.g., 22:00 to 06:00).
  bool isCurrentlyActive([DateTime? now]) {
    if (!isActive) return false;

    final time = now ?? DateTime.now();
    if (id.startsWith(quickBoostIdPrefix)) {
      return isQuickBoostActive(
        id,
        time,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
      );
    }
    if (daysOfWeek.isEmpty) return false;

    final currentDay = time.weekday; // 1 = Monday, 7 = Sunday
    final currentMinutes = time.hour * 60 + time.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // A zero-duration interval is never active.
    if (startMinutes == endMinutes) {
      return false;
    }

    // Case 2: Same-day interval (e.g. 09:00 to 17:00)
    if (startMinutes < endMinutes) {
      if (!daysOfWeek.contains(currentDay)) return false;
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }

    // Case 3: Midnight-crossing interval (e.g. 22:00 to 06:00)
    if (currentMinutes >= startMinutes) {
      // Late evening of the active day
      return daysOfWeek.contains(currentDay);
    } else if (currentMinutes < endMinutes) {
      // Early morning carrying over from previous day
      final prevDay = currentDay == 1 ? 7 : currentDay - 1;
      return daysOfWeek.contains(prevDay);
    }

    return false;
  }

  /// Checks if this schedule applies to a specific app package.
  bool appliesToPackage(String packageName) {
    if (targetPackageNames.isEmpty) return true;
    return targetPackageNames.contains(packageName);
  }

  String get formattedTimeRange {
    final sH = startHour.toString().padLeft(2, '0');
    final sM = startMinute.toString().padLeft(2, '0');
    final eH = endHour.toString().padLeft(2, '0');
    final eM = endMinute.toString().padLeft(2, '0');
    return '$sH:$sM - $eH:$eM';
  }

  String get formattedDays {
    if (daysOfWeek.length == 7) return 'Every day';
    if (daysOfWeek.length == 5 &&
        daysOfWeek.toSet().containsAll([1, 2, 3, 4, 5])) {
      return 'Weekdays';
    }
    if (daysOfWeek.length == 2 && daysOfWeek.toSet().containsAll([6, 7])) {
      return 'Weekends';
    }
    const dayNames = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final sorted = List<int>.from(daysOfWeek)..sort();
    return sorted
        .map((d) => dayNames[d] ?? '')
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  ScheduleModel copyWith({
    String? id,
    String? name,
    List<int>? daysOfWeek,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<String>? targetPackageNames,
    bool? isActive,
    InterventionMode? overrideMode,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      daysOfWeek: daysOfWeek ?? List.from(this.daysOfWeek),
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      targetPackageNames:
          targetPackageNames ?? List.from(this.targetPackageNames),
      isActive: isActive ?? this.isActive,
      overrideMode: overrideMode ?? this.overrideMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'daysOfWeek': daysOfWeek,
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
      'targetPackageNames': targetPackageNames,
      'isActive': isActive,
      'overrideMode': overrideMode?.name,
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [1, 2, 3, 4, 5],
      startHour: json['startHour'] as int? ?? 9,
      startMinute: json['startMinute'] as int? ?? 0,
      endHour: json['endHour'] as int? ?? 17,
      endMinute: json['endMinute'] as int? ?? 0,
      targetPackageNames: (json['targetPackageNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isActive: json['isActive'] as bool? ?? true,
      overrideMode: json['overrideMode'] != null
          ? InterventionMode.fromString(json['overrideMode'] as String?)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          _listEquals(daysOfWeek, other.daysOfWeek) &&
          startHour == other.startHour &&
          startMinute == other.startMinute &&
          endHour == other.endHour &&
          endMinute == other.endMinute &&
          _listEquals(targetPackageNames, other.targetPackageNames) &&
          isActive == other.isActive &&
          overrideMode == other.overrideMode;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      daysOfWeek.hashCode ^
      startHour.hashCode ^
      startMinute.hashCode ^
      endHour.hashCode ^
      endMinute.hashCode ^
      targetPackageNames.hashCode ^
      isActive.hashCode ^
      (overrideMode?.hashCode ?? 0);

  @override
  String toString() =>
      'ScheduleModel(id: $id, name: $name, range: $formattedTimeRange, isActive: $isActive)';

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
