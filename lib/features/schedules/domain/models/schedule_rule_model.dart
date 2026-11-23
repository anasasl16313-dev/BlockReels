import '../../../../core/models/quick_boost_window.dart';
import '../../../../core/models/intervention_mode.dart';
import '../../../../core/models/schedule_model.dart';
import '../../../../core/platform_channel/dtos/schedule_dto.dart';

/// Domain model representing a Focus Schedule Rule.
class ScheduleRuleModel {
  final String id;
  final String name;
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday (ISO 8601)
  final int startHour; // 0..23
  final int startMinute; // 0..59
  final int endHour; // 0..23
  final int endMinute; // 0..59
  final List<String> enabledPackageNames;
  final bool isActive;
  final InterventionMode? overrideMode;

  const ScheduleRuleModel({
    required this.id,
    required this.name,
    required this.daysOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.enabledPackageNames,
    this.isActive = true,
    this.overrideMode,
  });

  /// Alias for title.
  String get title => name;

  /// Alias for targetPackageNames.
  List<String> get targetPackageNames => enabledPackageNames;

  /// Alias for enabledPackages.
  List<String> get enabledPackages => enabledPackageNames;

  ScheduleRuleModel copyWith({
    String? id,
    String? name,
    List<int>? daysOfWeek,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    List<String>? enabledPackageNames,
    bool? isActive,
  }) {
    return ScheduleRuleModel(
      id: id ?? this.id,
      name: name ?? this.name,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      enabledPackageNames: enabledPackageNames ?? this.enabledPackageNames,
      isActive: isActive ?? this.isActive,
      overrideMode: overrideMode,
    );
  }

  ScheduleDto toDto() => ScheduleDto(
        id: id,
        name: name,
        daysOfWeek: daysOfWeek,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        enabledPackageNames: enabledPackageNames,
        isActive: isActive,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'daysOfWeek': daysOfWeek,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'enabledPackageNames': enabledPackageNames,
        'isActive': isActive,
        if (overrideMode != null) 'overrideMode': overrideMode!.name,
      };

  Map<String, dynamic> toJson() => toMap();

  factory ScheduleRuleModel.fromMap(Map<String, dynamic> map) =>
      ScheduleRuleModel(
        id: map['id'] as String? ?? '',
        name: (map['name'] as String?) ?? (map['title'] as String?) ?? '',
        daysOfWeek: (map['daysOfWeek'] as List<dynamic>?)?.cast<int>() ??
            const [1, 2, 3, 4, 5],
        startHour: map['startHour'] as int? ?? 0,
        startMinute: map['startMinute'] as int? ?? 0,
        endHour: map['endHour'] as int? ?? 0,
        endMinute: map['endMinute'] as int? ?? 0,
        enabledPackageNames: (map['enabledPackageNames'] as List<dynamic>? ??
                    map['enabledPackages'] as List<dynamic>? ??
                    map['targetPackageNames'] as List<dynamic>?)
                ?.cast<String>() ??
            const [],
        isActive: map['isActive'] as bool? ?? true,
        overrideMode: map['overrideMode'] == null
            ? null
            : InterventionMode.fromString(map['overrideMode'] as String?),
      );

  factory ScheduleRuleModel.fromJson(Map<String, dynamic> json) =>
      ScheduleRuleModel.fromMap(json);

  factory ScheduleRuleModel.fromCoreModel(ScheduleModel model) =>
      ScheduleRuleModel(
        id: model.id,
        name: model.name,
        daysOfWeek: model.daysOfWeek,
        startHour: model.startHour,
        startMinute: model.startMinute,
        endHour: model.endHour,
        endMinute: model.endMinute,
        enabledPackageNames: model.targetPackageNames,
        isActive: model.isActive,
        overrideMode: model.overrideMode,
      );

  ScheduleModel toCoreModel() => ScheduleModel(
        id: id,
        name: name,
        daysOfWeek: daysOfWeek,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        targetPackageNames: enabledPackageNames,
        isActive: isActive,
        overrideMode: overrideMode,
      );

  /// Evaluates whether this schedule is active at the given DateTime.
  bool isMatching(DateTime dateTime, {String? targetPackage}) {
    if (!isActive) return false;

    if (targetPackage != null && enabledPackageNames.isNotEmpty) {
      if (!enabledPackageNames.contains(targetPackage)) return false;
    }

    if (id.startsWith(quickBoostIdPrefix)) {
      return isQuickBoostActive(
        id,
        dateTime,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
      );
    }
    if (daysOfWeek.isEmpty) return false;

    final currentDay = dateTime.weekday; // 1 = Mon, 7 = Sun
    final nowMinutes = dateTime.hour * 60 + dateTime.minute;
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;

    // Zero-duration interval is never active
    if (startMinutes == endMinutes) {
      return false;
    }

    if (startMinutes < endMinutes) {
      // Normal schedule within same day (e.g. 09:00 - 17:00)
      if (!daysOfWeek.contains(currentDay)) return false;
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Overnight midnight-crossing schedule (e.g. 22:00 - 06:30)
      if (nowMinutes >= startMinutes) {
        // Today's night part
        return daysOfWeek.contains(currentDay);
      } else if (nowMinutes < endMinutes) {
        // Next morning part -> check if previous day was active
        final prevDay = currentDay == 1 ? 7 : currentDay - 1;
        return daysOfWeek.contains(prevDay);
      }
      return false;
    }
  }

  /// Alias for compatibility with core ScheduleModel.
  bool isCurrentlyActive([DateTime? now]) => isMatching(now ?? DateTime.now());

  /// Formatted time string (e.g. '09:00 - 17:00').
  String get formattedTimeRange {
    final sH = startHour.toString().padLeft(2, '0');
    final sM = startMinute.toString().padLeft(2, '0');
    final eH = endHour.toString().padLeft(2, '0');
    final eM = endMinute.toString().padLeft(2, '0');
    return '$sH:$sM - $eH:$eM';
  }

  /// Formatted days description (e.g. '5 days active', 'Every day', 'Weekdays').
  String get formattedDaysSummary => '${daysOfWeek.length} days active';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleRuleModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          _listEquals(daysOfWeek, other.daysOfWeek) &&
          startHour == other.startHour &&
          startMinute == other.startMinute &&
          endHour == other.endHour &&
          endMinute == other.endMinute &&
          _listEquals(enabledPackageNames, other.enabledPackageNames) &&
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
      enabledPackageNames.hashCode ^
      isActive.hashCode ^
      overrideMode.hashCode;

  @override
  String toString() =>
      'ScheduleRuleModel(id: $id, name: $name, range: $formattedTimeRange, active: $isActive)';

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
