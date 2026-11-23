import 'intervention_mode.dart';

/// Global preferences and security parameters for BlockReels.
class AppSettings {
  final bool isMasterEnabled;
  final String themeMode; // 'system', 'light', 'dark', 'amoled'
  final bool pinLockEnabled;
  final bool strictModeEnabled;
  final String? pinHash;
  final String? pinSalt;
  final int failedPinAttempts;
  final DateTime? lockoutUntil;
  final int defaultHoldDurationSeconds;
  final String
      breathingTechnique; // 'box_4_4_4_4', 'relaxing_4_7_8', 'coherent_5_5'
  final bool hapticFeedbackEnabled;
  final bool soundDuckingEnabled;
  final bool isOnboardingCompleted;
  final bool isForegroundServiceEnabled;
  final DateTime? lastBackupDate;
  final int schemaVersion;
  final int dailyTimeSavedGoalMinutes;
  final InterventionMode defaultInterventionMode;

  AppSettings({
    this.isMasterEnabled = true,
    this.themeMode = 'system',
    this.pinLockEnabled = false,
    this.strictModeEnabled = false,
    this.pinHash,
    this.pinSalt,
    this.failedPinAttempts = 0,
    this.lockoutUntil,
    this.defaultHoldDurationSeconds = 7,
    this.breathingTechnique = 'box_4_4_4_4',
    this.hapticFeedbackEnabled = true,
    this.soundDuckingEnabled = true,
    this.isOnboardingCompleted = false,
    this.isForegroundServiceEnabled = false,
    this.lastBackupDate,
    this.schemaVersion = 1,
    this.dailyTimeSavedGoalMinutes = 60,
    this.defaultInterventionMode = InterventionMode.mindfulPause,
  });

  bool get isLockedOut {
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil!);
  }

  int get remainingLockoutSeconds {
    if (lockoutUntil == null) return 0;
    final diff = lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Sentinel enabling explicit null-clearing of the nullable [lockoutUntil]
  /// field through copyWith (passing null clears; omitting preserves).
  static const Object _unset = Object();

  AppSettings copyWith({
    bool? isMasterEnabled,
    String? themeMode,
    bool? pinLockEnabled,
    bool? strictModeEnabled,
    Object? pinHash = _unset,
    Object? pinSalt = _unset,
    int? failedPinAttempts,
    Object? lockoutUntil = _unset,
    int? defaultHoldDurationSeconds,
    String? breathingTechnique,
    bool? hapticFeedbackEnabled,
    bool? soundDuckingEnabled,
    bool? isOnboardingCompleted,
    bool? isForegroundServiceEnabled,
    DateTime? lastBackupDate,
    int? schemaVersion,
    int? dailyTimeSavedGoalMinutes,
    InterventionMode? defaultInterventionMode,
  }) {
    return AppSettings(
      isMasterEnabled: isMasterEnabled ?? this.isMasterEnabled,
      themeMode: themeMode ?? this.themeMode,
      pinLockEnabled: pinLockEnabled ?? this.pinLockEnabled,
      strictModeEnabled: strictModeEnabled ?? this.strictModeEnabled,
      pinHash: identical(pinHash, _unset) ? this.pinHash : pinHash as String?,
      pinSalt: identical(pinSalt, _unset) ? this.pinSalt : pinSalt as String?,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      lockoutUntil: identical(lockoutUntil, _unset)
          ? this.lockoutUntil
          : lockoutUntil as DateTime?,
      defaultHoldDurationSeconds:
          defaultHoldDurationSeconds ?? this.defaultHoldDurationSeconds,
      breathingTechnique: breathingTechnique ?? this.breathingTechnique,
      hapticFeedbackEnabled:
          hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      soundDuckingEnabled: soundDuckingEnabled ?? this.soundDuckingEnabled,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      isForegroundServiceEnabled:
          isForegroundServiceEnabled ?? this.isForegroundServiceEnabled,
      lastBackupDate: lastBackupDate ?? this.lastBackupDate,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      dailyTimeSavedGoalMinutes:
          dailyTimeSavedGoalMinutes ?? this.dailyTimeSavedGoalMinutes,
      defaultInterventionMode:
          defaultInterventionMode ?? this.defaultInterventionMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isMasterEnabled': isMasterEnabled,
      'themeMode': themeMode,
      'pinLockEnabled': pinLockEnabled,
      'strictModeEnabled': strictModeEnabled,
      'pinHash': pinHash,
      'pinSalt': pinSalt,
      'failedPinAttempts': failedPinAttempts,
      'lockoutUntil': lockoutUntil?.toIso8601String(),
      'defaultHoldDurationSeconds': defaultHoldDurationSeconds,
      'breathingTechnique': breathingTechnique,
      'hapticFeedbackEnabled': hapticFeedbackEnabled,
      'soundDuckingEnabled': soundDuckingEnabled,
      'isOnboardingCompleted': isOnboardingCompleted,
      'isForegroundServiceEnabled': isForegroundServiceEnabled,
      'lastBackupDate': lastBackupDate?.toIso8601String(),
      'schemaVersion': schemaVersion,
      'dailyTimeSavedGoalMinutes': dailyTimeSavedGoalMinutes,
      'defaultInterventionMode': defaultInterventionMode.name,
    };
  }

  Map<String, dynamic> toBackupJson() {
    final json = toJson();
    json['pinLockEnabled'] = false;
    json['strictModeEnabled'] = false;
    json['pinHash'] = null;
    json['pinSalt'] = null;
    json['failedPinAttempts'] = 0;
    json['lockoutUntil'] = null;
    return json;
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      isMasterEnabled: json['isMasterEnabled'] as bool? ??
          (json['isMasterSwitchEnabled'] as bool? ?? true),
      themeMode: json['themeMode'] as String? ?? 'system',
      pinLockEnabled: json['pinLockEnabled'] as bool? ??
          (json['isPinProtectionEnabled'] as bool? ?? false),
      strictModeEnabled: json['strictModeEnabled'] as bool? ?? false,
      pinHash: json['pinHash'] as String?,
      pinSalt: json['pinSalt'] as String?,
      failedPinAttempts: json['failedPinAttempts'] as int? ?? 0,
      lockoutUntil: json['lockoutUntil'] != null
          ? DateTime.tryParse(json['lockoutUntil'] as String)
          : (json['lockoutUntilTimestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  json['lockoutUntilTimestamp'] as int)
              : null),
      defaultHoldDurationSeconds:
          json['defaultHoldDurationSeconds'] as int? ?? 7,
      breathingTechnique:
          json['breathingTechnique'] as String? ?? 'box_4_4_4_4',
      hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool? ??
          (json['isHapticFeedbackEnabled'] as bool? ?? true),
      soundDuckingEnabled: json['soundDuckingEnabled'] as bool? ??
          (json['isSoundEffectsEnabled'] as bool? ?? true),
      isOnboardingCompleted: json['isOnboardingCompleted'] as bool? ?? false,
      isForegroundServiceEnabled:
          json['isForegroundServiceEnabled'] as bool? ?? false,
      lastBackupDate: json['lastBackupDate'] != null
          ? DateTime.tryParse(json['lastBackupDate'] as String)
          : null,
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      dailyTimeSavedGoalMinutes:
          json['dailyTimeSavedGoalMinutes'] as int? ?? 60,
      defaultInterventionMode: InterventionMode.fromString(
        json['defaultInterventionMode'] as String?,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          isMasterEnabled == other.isMasterEnabled &&
          themeMode == other.themeMode &&
          pinLockEnabled == other.pinLockEnabled &&
          strictModeEnabled == other.strictModeEnabled &&
          pinHash == other.pinHash &&
          pinSalt == other.pinSalt &&
          failedPinAttempts == other.failedPinAttempts &&
          lockoutUntil == other.lockoutUntil &&
          defaultHoldDurationSeconds == other.defaultHoldDurationSeconds &&
          breathingTechnique == other.breathingTechnique &&
          hapticFeedbackEnabled == other.hapticFeedbackEnabled &&
          soundDuckingEnabled == other.soundDuckingEnabled &&
          isOnboardingCompleted == other.isOnboardingCompleted &&
          isForegroundServiceEnabled == other.isForegroundServiceEnabled &&
          schemaVersion == other.schemaVersion &&
          dailyTimeSavedGoalMinutes == other.dailyTimeSavedGoalMinutes &&
          defaultInterventionMode == other.defaultInterventionMode;

  @override
  int get hashCode =>
      isMasterEnabled.hashCode ^
      themeMode.hashCode ^
      pinLockEnabled.hashCode ^
      strictModeEnabled.hashCode ^
      (pinHash?.hashCode ?? 0) ^
      (pinSalt?.hashCode ?? 0) ^
      failedPinAttempts.hashCode ^
      (lockoutUntil?.hashCode ?? 0) ^
      defaultHoldDurationSeconds.hashCode ^
      breathingTechnique.hashCode ^
      hapticFeedbackEnabled.hashCode ^
      soundDuckingEnabled.hashCode ^
      isOnboardingCompleted.hashCode ^
      isForegroundServiceEnabled.hashCode ^
      schemaVersion.hashCode ^
      dailyTimeSavedGoalMinutes.hashCode ^
      defaultInterventionMode.hashCode;

  @override
  String toString() =>
      'AppSettings(theme: $themeMode, master: $isMasterEnabled, pin: $pinLockEnabled)';
}
