const String quickBoostLegacyId = 'quick_boost';
const String quickBoostIdPrefix = 'quick_boost_';

bool isQuickBoostId(String id) =>
    id == quickBoostLegacyId || id.startsWith(quickBoostIdPrefix);

DateTime? quickBoostStartedAt(String id) {
  if (!id.startsWith(quickBoostIdPrefix)) return null;
  final epochMs = int.tryParse(id.substring(quickBoostIdPrefix.length));
  if (epochMs == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(epochMs);
}

int quickBoostDurationMinutes(
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
) {
  final startMinutes = startHour * 60 + startMinute;
  final endMinutes = endHour * 60 + endMinute;
  if (startMinutes == endMinutes) return 0;
  var duration = endMinutes - startMinutes;
  if (duration < 0) duration += 24 * 60;
  return duration;
}

DateTime? quickBoostEndsAt(
  String id, {
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
}) {
  final start = quickBoostStartedAt(id);
  if (start == null) return null;
  final minutes = quickBoostDurationMinutes(
    startHour,
    startMinute,
    endHour,
    endMinute,
  );
  if (minutes <= 0) return null;
  return start.add(Duration(minutes: minutes));
}

bool isQuickBoostActive(
  String id,
  DateTime now, {
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
}) {
  final start = quickBoostStartedAt(id);
  if (start == null) return false;
  final end = quickBoostEndsAt(
    id,
    startHour: startHour,
    startMinute: startMinute,
    endHour: endHour,
    endMinute: endMinute,
  );
  if (end == null) return false;
  return !now.isBefore(start) && now.isBefore(end);
}
