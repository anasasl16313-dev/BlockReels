/// Real-time metrics snapshot returned directly by the native background service.
class RealtimeMetricsDto {
  final int totalBlockedToday;
  final Map<String, int> byApp;
  final String lastBlockedPackage;
  final int lastBlockedTimestamp;
  final int serviceUptimeMs;

  const RealtimeMetricsDto({
    required this.totalBlockedToday,
    this.byApp = const {},
    this.lastBlockedPackage = '',
    this.lastBlockedTimestamp = 0,
    this.serviceUptimeMs = 0,
  });

  factory RealtimeMetricsDto.empty() => const RealtimeMetricsDto(
        totalBlockedToday: 0,
        byApp: {},
        lastBlockedPackage: '',
        lastBlockedTimestamp: 0,
        serviceUptimeMs: 0,
      );

  /// Defensive scalar extraction: hostile or type-confused native payloads
  /// degrade to safe defaults instead of crashing the isolate.
  static int _safeInt(dynamic value, int fallback) =>
      value is int ? value : fallback;

  static String _safeString(dynamic value, String fallback) =>
      value is String ? value : fallback;

  factory RealtimeMetricsDto.fromJson(Map<String, dynamic> json) {
    final rawByApp = json['byApp'] is Map ? json['byApp'] as Map : null;
    final Map<String, int> parsedByApp = {};
    if (rawByApp != null) {
      rawByApp.forEach((k, v) {
        if (v is int || v is num) parsedByApp[k.toString()] = v.toInt();
      });
    }

    return RealtimeMetricsDto(
      totalBlockedToday: _safeInt(
        json['totalBlockedToday'] ??
            json['todayBlocked'] ??
            json['totalBlocked'],
        0,
      ),
      byApp: parsedByApp,
      lastBlockedPackage: _safeString(json['lastBlockedPackage'], ''),
      lastBlockedTimestamp: _safeInt(json['lastBlockedTimestamp'], 0),
      serviceUptimeMs: _safeInt(json['serviceUptimeMs'], 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalBlockedToday': totalBlockedToday,
        'byApp': byApp,
        'lastBlockedPackage': lastBlockedPackage,
        'lastBlockedTimestamp': lastBlockedTimestamp,
        'serviceUptimeMs': serviceUptimeMs,
      };

  @override
  String toString() =>
      'RealtimeMetricsDto(today: $totalBlockedToday, uptime: ${serviceUptimeMs}ms, lastApp: $lastBlockedPackage)';
}
