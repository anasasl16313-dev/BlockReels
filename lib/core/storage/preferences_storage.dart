import 'package:shared_preferences/shared_preferences.dart';

/// Fast key-value access layer backed by SharedPreferences for cold startup bootstrap flags.
class PreferencesStorage {
  static const String _kOnboardingCompleted = 'key_is_onboarding_completed';
  static const String _kThemeMode = 'key_theme_mode';
  static const String _kIsMasterEnabled = 'key_is_master_enabled';
  static const String _kPinLockoutUntil = 'key_pin_lockout_until';
  static const String _kFailedPinAttempts = 'key_failed_pin_attempts';
  static const String _kIsFirstLaunch = 'key_is_first_launch';

  final SharedPreferences _prefs;

  PreferencesStorage(this._prefs);

  static Future<PreferencesStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesStorage(prefs);
  }

  bool get isOnboardingCompleted =>
      _prefs.getBool(_kOnboardingCompleted) ?? false;

  Future<bool> setOnboardingCompleted(bool value) =>
      _prefs.setBool(_kOnboardingCompleted, value);

  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';

  Future<bool> setThemeMode(String value) =>
      _prefs.setString(_kThemeMode, value);

  bool get isMasterEnabled => _prefs.getBool(_kIsMasterEnabled) ?? true;

  Future<bool> setMasterEnabled(bool value) =>
      _prefs.setBool(_kIsMasterEnabled, value);

  int? get pinLockoutUntilTimestamp => _prefs.getInt(_kPinLockoutUntil);

  Future<bool> setPinLockoutUntilTimestamp(int? value) {
    if (value == null) {
      return _prefs.remove(_kPinLockoutUntil);
    }
    return _prefs.setInt(_kPinLockoutUntil, value);
  }

  int get failedPinAttempts => _prefs.getInt(_kFailedPinAttempts) ?? 0;

  Future<bool> setFailedPinAttempts(int count) =>
      _prefs.setInt(_kFailedPinAttempts, count);

  bool get isFirstLaunch => _prefs.getBool(_kIsFirstLaunch) ?? true;

  Future<bool> setFirstLaunchCompleted() =>
      _prefs.setBool(_kIsFirstLaunch, false);

  Future<bool> clear() => _prefs.clear();
}
