/// State model representing PIN security configuration, lockout timers, and strict mode state.
class PinSecurityState {
  final bool isPinEnabled;
  final String? pinHash;
  final String? pinSalt;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final bool isStrictModeActive;

  const PinSecurityState({
    this.isPinEnabled = false,
    this.pinHash,
    this.pinSalt,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.isStrictModeActive = false,
  });

  /// Evaluates whether the user is currently locked out due to excessive failed attempts.
  bool isLockedOut([DateTime? now]) {
    if (lockoutUntil == null) return false;
    final time = now ?? DateTime.now();
    return time.isBefore(lockoutUntil!);
  }

  /// Calculates remaining lockout cooldown in seconds.
  int lockoutSecondsRemaining([DateTime? now]) {
    if (lockoutUntil == null) return 0;
    final time = now ?? DateTime.now();
    final diff = lockoutUntil!.difference(time).inSeconds;
    return diff > 0 ? diff : 0;
  }

  static const Object _unset = Object();

  PinSecurityState copyWith({
    bool? isPinEnabled,
    Object? pinHash = _unset,
    Object? pinSalt = _unset,
    int? failedAttempts,
    Object? lockoutUntil = _unset,
    bool? isStrictModeActive,
  }) {
    return PinSecurityState(
      isPinEnabled: isPinEnabled ?? this.isPinEnabled,
      pinHash: identical(pinHash, _unset) ? this.pinHash : pinHash as String?,
      pinSalt: identical(pinSalt, _unset) ? this.pinSalt : pinSalt as String?,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: identical(lockoutUntil, _unset)
          ? this.lockoutUntil
          : lockoutUntil as DateTime?,
      isStrictModeActive: isStrictModeActive ?? this.isStrictModeActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'isPinEnabled': isPinEnabled,
        'pinHash': pinHash,
        'pinSalt': pinSalt,
        'failedAttempts': failedAttempts,
        'lockoutUntil': lockoutUntil?.toIso8601String(),
        'isStrictModeActive': isStrictModeActive,
      };

  factory PinSecurityState.fromJson(Map<String, dynamic> json) =>
      PinSecurityState(
        isPinEnabled: json['isPinEnabled'] as bool? ?? false,
        pinHash: json['pinHash'] as String?,
        pinSalt: json['pinSalt'] as String?,
        failedAttempts: json['failedAttempts'] as int? ?? 0,
        lockoutUntil: json['lockoutUntil'] != null
            ? DateTime.tryParse(json['lockoutUntil'] as String)
            : null,
        isStrictModeActive: json['isStrictModeActive'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PinSecurityState &&
          runtimeType == other.runtimeType &&
          isPinEnabled == other.isPinEnabled &&
          pinHash == other.pinHash &&
          pinSalt == other.pinSalt &&
          failedAttempts == other.failedAttempts &&
          lockoutUntil == other.lockoutUntil &&
          isStrictModeActive == other.isStrictModeActive;

  @override
  int get hashCode =>
      isPinEnabled.hashCode ^
      (pinHash?.hashCode ?? 0) ^
      (pinSalt?.hashCode ?? 0) ^
      failedAttempts.hashCode ^
      (lockoutUntil?.hashCode ?? 0) ^
      isStrictModeActive.hashCode;

  @override
  String toString() =>
      'PinSecurityState(enabled: $isPinEnabled, fails: $failedAttempts, locked: ${isLockedOut()})';
}
