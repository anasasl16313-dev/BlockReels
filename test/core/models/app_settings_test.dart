import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/models/intervention_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings Model Tests', () {
    test('instantiates with sane defaults', () {
      final settings = AppSettings();

      expect(settings.isMasterEnabled, isTrue);
      expect(settings.themeMode, 'system');
      expect(settings.pinLockEnabled, isFalse);
      expect(settings.pinHash, isNull);
      expect(settings.pinSalt, isNull);
      expect(settings.failedPinAttempts, 0);
      expect(settings.lockoutUntil, isNull);
      expect(settings.isLockedOut, isFalse);
      expect(settings.remainingLockoutSeconds, 0);
      expect(settings.defaultHoldDurationSeconds, 7);
      expect(settings.breathingTechnique, 'box_4_4_4_4');
      expect(settings.hapticFeedbackEnabled, isTrue);
      expect(settings.soundDuckingEnabled, isTrue);
      expect(settings.isOnboardingCompleted, isFalse);
      expect(settings.schemaVersion, 1);
      expect(settings.dailyTimeSavedGoalMinutes, 60);
      expect(settings.defaultInterventionMode, InterventionMode.mindfulPause);
    });

    test('lockout calculation evaluates active countdown accurately', () {
      final futureLockout = DateTime.now().add(const Duration(seconds: 45));
      final lockedSettings = AppSettings(lockoutUntil: futureLockout);

      expect(lockedSettings.isLockedOut, isTrue);
      expect(lockedSettings.remainingLockoutSeconds, greaterThan(30));

      final pastLockout = DateTime.now().subtract(const Duration(seconds: 10));
      final unlockedSettings = AppSettings(lockoutUntil: pastLockout);

      expect(unlockedSettings.isLockedOut, isFalse);
      expect(unlockedSettings.remainingLockoutSeconds, 0);
    });

    test('copyWith updates specified properties', () {
      final settings = AppSettings();
      final updated = settings.copyWith(
        themeMode: 'amoled',
        pinLockEnabled: true,
        strictModeEnabled: true,
        pinHash: 'hash123',
        pinSalt: 'salt456',
        defaultHoldDurationSeconds: 10,
        isOnboardingCompleted: true,
      );

      expect(updated.themeMode, 'amoled');
      expect(updated.pinLockEnabled, isTrue);
      expect(updated.strictModeEnabled, isTrue);
      expect(updated.pinHash, 'hash123');
      expect(updated.pinSalt, 'salt456');
      expect(updated.defaultHoldDurationSeconds, 10);
      expect(updated.isOnboardingCompleted, isTrue);
      expect(updated.isMasterEnabled, isTrue);
    });

    test('JSON serialization roundtrip maintains all settings fields', () {
      final lockoutTime = DateTime.now().add(const Duration(minutes: 5));
      final backupTime = DateTime.now();

      final settings = AppSettings(
        isMasterEnabled: false,
        themeMode: 'dark',
        pinLockEnabled: true,
        strictModeEnabled: true,
        pinHash: 'secure_hash',
        pinSalt: 'random_salt',
        failedPinAttempts: 3,
        lockoutUntil: lockoutTime,
        defaultHoldDurationSeconds: 12,
        breathingTechnique: 'relaxing_4_7_8',
        hapticFeedbackEnabled: false,
        soundDuckingEnabled: false,
        isOnboardingCompleted: true,
        isForegroundServiceEnabled: true,
        lastBackupDate: backupTime,
        schemaVersion: 2,
        dailyTimeSavedGoalMinutes: 90,
        defaultInterventionMode: InterventionMode.strictBlock,
      );

      final json = settings.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.isMasterEnabled, settings.isMasterEnabled);
      expect(restored.themeMode, settings.themeMode);
      expect(restored.pinLockEnabled, settings.pinLockEnabled);
      expect(restored.strictModeEnabled, settings.strictModeEnabled);
      expect(restored.pinHash, settings.pinHash);
      expect(restored.pinSalt, settings.pinSalt);
      expect(restored.failedPinAttempts, settings.failedPinAttempts);
      expect(restored.defaultHoldDurationSeconds,
          settings.defaultHoldDurationSeconds);
      expect(restored.breathingTechnique, settings.breathingTechnique);
      expect(restored.hapticFeedbackEnabled, settings.hapticFeedbackEnabled);
      expect(restored.soundDuckingEnabled, settings.soundDuckingEnabled);
      expect(restored.isOnboardingCompleted, settings.isOnboardingCompleted);
      expect(restored.isForegroundServiceEnabled,
          settings.isForegroundServiceEnabled);
      expect(restored.schemaVersion, settings.schemaVersion);
      expect(restored.dailyTimeSavedGoalMinutes,
          settings.dailyTimeSavedGoalMinutes);
      expect(
          restored.defaultInterventionMode, settings.defaultInterventionMode);
    });
    test('backup JSON omits PIN secrets and lockout state', () {
      final settings = AppSettings(
        isMasterEnabled: false,
        themeMode: 'dark',
        pinLockEnabled: true,
        strictModeEnabled: true,
        pinHash: 'secret_hash',
        pinSalt: 'secret_salt',
        failedPinAttempts: 4,
        lockoutUntil: DateTime.now().add(const Duration(minutes: 15)),
      );

      final backup = settings.toBackupJson();

      expect(backup['pinLockEnabled'], isFalse);
      expect(backup['strictModeEnabled'], isFalse);
      expect(backup['pinHash'], isNull);
      expect(backup['pinSalt'], isNull);
      expect(backup['failedPinAttempts'], 0);
      expect(backup['lockoutUntil'], isNull);

      final restored = AppSettings.fromJson(backup);
      expect(restored.pinLockEnabled, isFalse);
      expect(restored.strictModeEnabled, isFalse);
      expect(restored.pinHash, isNull);
      expect(restored.pinSalt, isNull);
    });
  });
}
