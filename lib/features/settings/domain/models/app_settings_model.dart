import '../../../../core/models/app_settings.dart';
import 'app_theme_mode.dart';

/// Domain settings configuration model for user customization and backup serialization.
class AppSettingsModel {
  final AppThemeMode themeMode;
  final bool hapticsEnabled;
  final int defaultHoldDurationSeconds;
  final String customMindfulnessMessage;
  final bool isPinEnabled;
  final bool isForegroundServiceEnabled;

  const AppSettingsModel({
    this.themeMode = AppThemeMode.system,
    this.hapticsEnabled = true,
    this.defaultHoldDurationSeconds = 10,
    this.customMindfulnessMessage = 'Take a deep breath.',
    this.isPinEnabled = false,
    this.isForegroundServiceEnabled = false,
  });

  AppSettingsModel copyWith({
    AppThemeMode? themeMode,
    bool? hapticsEnabled,
    int? defaultHoldDurationSeconds,
    String? customMindfulnessMessage,
    bool? isPinEnabled,
    bool? isForegroundServiceEnabled,
  }) {
    return AppSettingsModel(
      themeMode: themeMode ?? this.themeMode,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      defaultHoldDurationSeconds:
          defaultHoldDurationSeconds ?? this.defaultHoldDurationSeconds,
      customMindfulnessMessage:
          customMindfulnessMessage ?? this.customMindfulnessMessage,
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      isForegroundServiceEnabled:
          isForegroundServiceEnabled ?? this.isForegroundServiceEnabled,
    );
  }

  Map<String, dynamic> toJson({bool includeSecrets = false}) => {
        'themeMode': themeMode.name,
        'hapticsEnabled': hapticsEnabled,
        'defaultHoldDurationSeconds': defaultHoldDurationSeconds,
        'customMindfulnessMessage': customMindfulnessMessage,
        'isPinEnabled': isPinEnabled,
        'isForegroundServiceEnabled': isForegroundServiceEnabled,
      };

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) =>
      AppSettingsModel(
        themeMode: AppThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => AppThemeMode.system,
        ),
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        defaultHoldDurationSeconds:
            json['defaultHoldDurationSeconds'] as int? ?? 10,
        customMindfulnessMessage: json['customMindfulnessMessage'] as String? ??
            'Take a deep breath.',
        isPinEnabled: json['isPinEnabled'] as bool? ?? false,
        isForegroundServiceEnabled:
            json['isForegroundServiceEnabled'] as bool? ?? false,
      );

  factory AppSettingsModel.fromCoreSettings(AppSettings core) {
    final theme = AppThemeMode.values.firstWhere(
      (m) => m.name == core.themeMode,
      orElse: () => AppThemeMode.system,
    );
    return AppSettingsModel(
      themeMode: theme,
      hapticsEnabled: core.hapticFeedbackEnabled,
      defaultHoldDurationSeconds: core.defaultHoldDurationSeconds,
      customMindfulnessMessage: 'Take a deep breath.',
      isPinEnabled: core.pinLockEnabled,
      isForegroundServiceEnabled: core.isForegroundServiceEnabled,
    );
  }

  AppSettings toCoreSettings([AppSettings? current]) {
    final base = current ?? AppSettings();
    return base.copyWith(
      themeMode: themeMode.name,
      hapticFeedbackEnabled: hapticsEnabled,
      defaultHoldDurationSeconds: defaultHoldDurationSeconds,
      pinLockEnabled: isPinEnabled,
      isForegroundServiceEnabled: isForegroundServiceEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsModel &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          hapticsEnabled == other.hapticsEnabled &&
          defaultHoldDurationSeconds == other.defaultHoldDurationSeconds &&
          customMindfulnessMessage == other.customMindfulnessMessage &&
          isPinEnabled == other.isPinEnabled &&
          isForegroundServiceEnabled == other.isForegroundServiceEnabled;

  @override
  int get hashCode =>
      themeMode.hashCode ^
      hapticsEnabled.hashCode ^
      defaultHoldDurationSeconds.hashCode ^
      customMindfulnessMessage.hashCode ^
      isPinEnabled.hashCode ^
      isForegroundServiceEnabled.hashCode;

  @override
  String toString() =>
      'AppSettingsModel(theme: $themeMode, haptics: $hapticsEnabled, hold: ${defaultHoldDurationSeconds}s)';
}
