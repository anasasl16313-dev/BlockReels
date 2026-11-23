import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/app_settings.dart';
import '../models/history_log.dart';
import '../models/rule_model.dart';
import '../models/schedule_model.dart';
import '../models/whitelist_item.dart';

/// Parses every present section before any restore can mutate storage.
class ValidatedBackup {
  final List<RuleModel>? rules;
  final List<ScheduleModel>? schedules;
  final AppSettings? settings;
  final List<WhitelistItem>? whitelist;
  final List<HistoryLog>? history;
  const ValidatedBackup._(
      {this.rules,
      this.schedules,
      this.settings,
      this.whitelist,
      this.history});

  static const maxCharacters = 4 * 1024 * 1024;
  static const maxRecords = 4096;

  static bool _bounded(Object? value, int depth) {
    if (depth > 10) return false;
    if (value is String) return value.length <= 4096;
    if (value is List) {
      return value.length <= maxRecords &&
          value.every((item) => _bounded(item, depth + 1));
    }
    if (value is Map) {
      return value.length <= 64 &&
          value.entries.every((entry) =>
              entry.key is String &&
              (entry.key as String).length <= 128 &&
              _bounded(entry.value, depth + 1));
    }
    return true;
  }

  // Bound the JSON decoder's allocations before constructing nested containers.
  static bool _fitsDecoderBudget(String text) {
    if (text.length > maxCharacters) return false;
    var depth = 0;
    var separators = 0;
    var quoted = false;
    for (var index = 0; index < text.length; index++) {
      final char = text.codeUnitAt(index);
      if (quoted && char == 92) {
        index++;
      } else if (char == 34) {
        quoted = !quoted;
      } else if (!quoted) {
        if (char == 91 || char == 123) {
          if (++depth > 11) return false;
        } else if (char == 93 || char == 125) {
          if (--depth < 0) return false;
        } else if (char == 44 && ++separators > 256 * 1024) {
          return false;
        }
      }
    }
    return !quoted && depth == 0;
  }

  static ValidatedBackup? parse(String text) {
    try {
      if (!_fitsDecoderBudget(text)) return null;
      final root = jsonDecode(text) as Map<String, dynamic>;
      if (!_bounded(root, 0)) return null;
      if (root['version'] is! int || root['version'] != 1) {
        return null;
      }
      final data = root['data'] as Map<String, dynamic>;
      if (root['checksum'] !=
          sha256.convert(utf8.encode(jsonEncode(data))).toString()) {
        return null;
      }
      List<T>? section<T>(String key, T Function(Map<String, dynamic>) decode) {
        if (!data.containsKey(key)) return null;
        return (data[key] as List)
            .map((item) => decode(item as Map<String, dynamic>))
            .toList();
      }

      final settings = data.containsKey('settings')
          ? AppSettings.fromJson(data['settings'] as Map<String, dynamic>)
          : null;
      if (settings != null &&
          settings.pinLockEnabled &&
          (settings.pinHash == null || settings.pinSalt == null)) {
        return null;
      }
      final result = ValidatedBackup._(
        rules: section('rules', RuleModel.fromJson),
        schedules: section(
            'schedules',
            (json) => ScheduleModel.fromJson({
                  ...json,
                  // Version 1 also accepts the former feature/bridge field names.
                  'name': json['name'] ?? json['title'],
                  'targetPackageNames': json['targetPackageNames'] ??
                      json['enabledPackageNames'] ??
                      json['enabledPackages'] ??
                      json['enabledApps'],
                })),
        settings: settings,
        whitelist: section('whitelist', WhitelistItem.fromJson),
        history: section('history', HistoryLog.fromJson),
      );
      bool identifier(String value) => value.trim().isNotEmpty;
      bool unique(Iterable<String> values) {
        final seen = <String>{};
        return values.every((value) => identifier(value) && seen.add(value));
      }

      if (settings != null &&
          (settings.defaultHoldDurationSeconds < 5 ||
              settings.defaultHoldDurationSeconds > 30)) {
        return null;
      }
      final packagePattern =
          RegExp(r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)*$');
      bool packageName(String value) =>
          value.length <= 255 && packagePattern.hasMatch(value);
      if (result.rules?.any((rule) =>
              !packageName(rule.packageName) ||
              rule.holdDurationSeconds < 1 ||
              rule.holdDurationSeconds > 3600) ??
          false) {
        return null;
      }
      if (result.rules != null &&
          (!unique(result.rules!.map((r) => r.id)) ||
              !unique(result.rules!.map((r) => r.packageName)))) {
        return null;
      }
      if (result.schedules != null) {
        if (!unique(result.schedules!.map((s) => s.id))) {
          return null;
        }
        for (final schedule in result.schedules!) {
          if (schedule.daysOfWeek.any((day) => day < 1 || day > 7) ||
              schedule.daysOfWeek.toSet().length !=
                  schedule.daysOfWeek.length ||
              schedule.startHour < 0 ||
              schedule.startHour > 23 ||
              schedule.endHour < 0 ||
              schedule.endHour > 23 ||
              schedule.startMinute < 0 ||
              schedule.startMinute > 59 ||
              schedule.endMinute < 0 ||
              schedule.endMinute > 59 ||
              !schedule.targetPackageNames.every(packageName) ||
              !unique(schedule.targetPackageNames)) {
            return null;
          }
        }
      }
      if (result.whitelist != null &&
          (!unique(result.whitelist!.map((w) => w.id)) ||
              result.whitelist!.any((w) =>
                  !identifier(w.packageName) || !identifier(w.componentId)))) {
        return null;
      }
      if (result.history != null &&
          (!unique(result.history!.map((h) => h.id)) ||
              result.history!.any((h) => !identifier(h.packageName)))) {
        return null;
      }
      if (result.rules == null &&
          result.schedules == null &&
          result.settings == null &&
          result.whitelist == null &&
          result.history == null) {
        return null;
      }
      return result;
    } catch (_) {
      return null;
    }
  }
}
