/// Data transfer object carrying global intervention parameters across the platform bridge.
class InterventionConfigDto {
  final String defaultMode; // 'AUTO_BACK' | 'MINDFUL_PAUSE' | 'STRICT_BLOCK'
  final int holdDurationSeconds;
  final String customMessage;
  final bool pinProtected;
  final bool soundEnabled;
  final bool hapticsEnabled;

  const InterventionConfigDto({
    String? defaultMode,
    String? mode,
    this.holdDurationSeconds = 7,
    this.customMessage = 'Take a deep breath. Be intentional.',
    this.pinProtected = false,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  }) : defaultMode = defaultMode ?? mode ?? 'MINDFUL_PAUSE';

  String get mode => defaultMode;
  String get interventionMode => defaultMode;

  /// Defensive scalar extraction for hostile native payloads.
  static int _safeInt(dynamic value, int fallback) =>
      value is int ? value : fallback;

  static String _safeString(dynamic value, String fallback) =>
      value is String ? value : fallback;

  static bool _safeBool(dynamic value, bool fallback) =>
      value is bool ? value : fallback;

  factory InterventionConfigDto.fromJson(Map<String, dynamic> json) =>
      InterventionConfigDto(
        defaultMode: _safeString(
          json['defaultMode'] ?? json['mode'] ?? json['interventionMode'],
          'MINDFUL_PAUSE',
        ),
        holdDurationSeconds: _safeInt(json['holdDurationSeconds'], 7),
        customMessage: _safeString(
          json['customMessage'],
          'Take a deep breath. Be intentional.',
        ),
        pinProtected:
            _safeBool(json['pinProtected'] ?? json['isPinProtected'], false),
        soundEnabled: _safeBool(json['soundEnabled'], true),
        hapticsEnabled: _safeBool(json['hapticsEnabled'], true),
      );

  Map<String, dynamic> toJson() => {
        'defaultMode': defaultMode,
        'mode': defaultMode,
        'interventionMode': defaultMode,
        'holdDurationSeconds': holdDurationSeconds,
        'customMessage': customMessage,
        'pinProtected': pinProtected,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
      };

  @override
  String toString() =>
      'InterventionConfigDto(mode: $defaultMode, hold: ${holdDurationSeconds}s, pin: $pinProtected)';
}
