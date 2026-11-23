import 'dart:io';
import 'package:block_reels/core/platform_channel/mock_platform_bridge.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/core/storage/hive_storage_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveStorageRepository storage;
  late MockPlatformBridge bridge;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_notifier_test_');
    storage = HiveStorageRepository();
    await storage.init(customPath: tempDir.path);
    bridge = MockPlatformBridge();

    container = ProviderContainer(
      overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    bridge.dispose();
    await storage.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SettingsNotifier State Management Tests', () {
    test('initializes and loads settings', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      final settings = container.read(settingsProvider);
      expect(settings.isMasterEnabled, isTrue);
      expect(settings.defaultHoldDurationSeconds, 7);
    });

    test('toggleMasterSwitch updates state, storage, and bridge', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.toggleMasterSwitch(false);

      final state = container.read(settingsProvider);
      expect(state.isMasterEnabled, isFalse);

      final stored = await storage.getSettings();
      expect(stored.isMasterEnabled, isFalse);

      expect(bridge.updateSettingsCalls.isNotEmpty, isTrue);
    });

    test('setThemeMode updates theme setting in storage', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setThemeMode('amoled');

      final state = container.read(settingsProvider);
      expect(state.themeMode, 'amoled');

      final stored = await storage.getSettings();
      expect(stored.themeMode, 'amoled');
    });

    test('setPinLock, failed attempts and progressive lockout', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.setPinLock(
        enabled: true,
        pinHash: 'hash_abc',
        pinSalt: 'salt_xyz',
      );

      var state = container.read(settingsProvider);
      expect(state.pinLockEnabled, isTrue);
      expect(state.pinHash, 'hash_abc');
      expect(state.failedPinAttempts, 0);

      // 1st failed attempt
      await notifier.recordFailedPinAttempt();
      state = container.read(settingsProvider);
      expect(state.failedPinAttempts, 1);
      expect(state.isLockedOut, isFalse);

      // 2nd failed attempt
      await notifier.recordFailedPinAttempt();
      // 3rd failed attempt -> triggers lockout
      await notifier.recordFailedPinAttempt();
      state = container.read(settingsProvider);
      expect(state.failedPinAttempts, 3);
      expect(state.isLockedOut, isTrue);

      // Reset
      await notifier.resetFailedPinAttempts();
      state = container.read(settingsProvider);
      expect(state.failedPinAttempts, 0);
      expect(state.isLockedOut, isFalse);
    });

    test('toggleForegroundService starts/stops service on platform bridge',
        () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.loadSettings();

      await notifier.toggleForegroundService(true);
      expect(
          container.read(settingsProvider).isForegroundServiceEnabled, isTrue);
      expect(bridge.startForegroundCalls, 1);

      await notifier.toggleForegroundService(false);
      expect(
          container.read(settingsProvider).isForegroundServiceEnabled, isFalse);
      expect(bridge.stopForegroundCalls, 1);
    });
  });
}
