import '../../models/schedule_model.dart';

/// Data transfer object carrying focus schedule configurations across the platform channel.
class ScheduleDto {
  final String id;
  final String title;
  final bool isActive;
  final List<int> daysOfWeek; // 1 = Monday, ..., 7 = Sunday
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final List<String> enabledPackages;

  const ScheduleDto({
    required this.id,
    String? title,
    String? name,
    this.isActive = true,
    required this.daysOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    List<String>? enabledPackages,
    List<String>? enabledPackageNames,
  })  : title = title ?? name ?? '',
        enabledPackages = enabledPackages ?? enabledPackageNames ?? const [];

  String get name => title;
  List<String> get enabledPackageNames => enabledPackages;

  factory ScheduleDto.fromModel(ScheduleModel model) => ScheduleDto(
        id: model.id,
        title: model.name,
        isActive: model.isActive,
        daysOfWeek: model.daysOfWeek,
        startHour: model.startHour,
        startMinute: model.startMinute,
        endHour: model.endHour,
        endMinute: model.endMinute,
        enabledPackages: model.targetPackageNames,
      );

  /// Defensive scalar extraction for hostile native payloads.
  static int _safeInt(dynamic value, int fallback) =>
      value is int ? value : fallback;

  static String _safeString(dynamic value, String fallback) =>
      value is String ? value : fallback;

  static bool _safeBool(dynamic value, bool fallback) =>
      value is bool ? value : fallback;

  factory ScheduleDto.fromJson(Map<String, dynamic> json) => ScheduleDto(
        id: _safeString(json['id'], ''),
        title: _safeString(json['title'] ?? json['name'], ''),
        isActive: _safeBool(json['isActive'], true),
        daysOfWeek: json['daysOfWeek'] is List
            ? (json['daysOfWeek'] as List).whereType<int>().toList()
            : const [],
        startHour: _safeInt(json['startHour'], 0),
        startMinute: _safeInt(json['startMinute'], 0),
        endHour: _safeInt(json['endHour'], 0),
        endMinute: _safeInt(json['endMinute'], 0),
        enabledPackages: (json['enabledPackages'] ??
                json['enabledApps'] ??
                json['enabledPackageNames'] ??
                json['targetPackageNames']) is List
            ? ((json['enabledPackages'] ??
                    json['enabledApps'] ??
                    json['enabledPackageNames'] ??
                    json['targetPackageNames']) as List)
                .whereType<String>()
                .toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'name': title,
        'isActive': isActive,
        'daysOfWeek': daysOfWeek,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'enabledPackages': enabledPackages,
        'enabledApps': enabledPackages,
        'enabledPackageNames': enabledPackages,
      };

  @override
  String toString() =>
      'ScheduleDto(id: $id, title: $title, active: $isActive, days: $daysOfWeek)';
}
