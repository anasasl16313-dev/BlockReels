// Real 120000-iteration PBKDF2 runs can exceed 30s on a contended build host.
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';

import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/features/pin_lock/pin_lock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageRepository storage;
  late FakePlatformBridge bridge;
  late ProviderContainer container;
  late PinSecurityController controller;
  final now = DateTime(2026, 8, 19, 12);

  setUp(() async {
    storage = FakeStorageRepository();
    bridge = FakePlatformBridge();
    container = ProviderContainer(
      overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
    );
    await container.read(settingsProvider.notifier).loadSettings();
    controller = PinSecurityController(
      storage,
      container.read(settingsProvider.notifier),
    );
    controller.setMockNow(now);
  });

  tearDown(() async {
    await pumpEventQueue();
    controller.dispose();
    container.dispose();
    await bridge.dispose();
  });

  test(
    'isolate PBKDF2 matches a 120000-iteration independent test vector',
    () async {
      const encoded =
          'pbkdf2_sha256\$120000\$74dSG9NHwEFDb6uXDpu6+cIARL9afs/78qV2pbz3ZFg=';
      expect(CryptoPinUtils.defaultIterations, 120000);
      expect(await CryptoPinUtils.hashPin('1234', 'test_salt'), encoded);
      expect(
        await CryptoPinUtils.verifyPin('1234', encoded, 'test_salt'),
        isTrue,
      );
      expect(
        await CryptoPinUtils.verifyPin('4321', encoded, 'test_salt'),
        isFalse,
      );
    },
  );

  test('single-salt legacy credentials migrate after verification', () async {
    const salt = 'older_salt';
    final notifier = container.read(settingsProvider.notifier);
    await notifier.updateSettings(
      notifier.currentSettings.copyWith(
        pinLockEnabled: true,
        pinSalt: salt,
        pinHash: sha256.convert(utf8.encode('$salt:2468')).toString(),
      ),
    );
    expect(await controller.verifyPin('2468'), isTrue);
    expect(storage.settings.pinHash, startsWith('pbkdf2_sha256\$120000\$'));
    expect(storage.settings.pinSalt, isNot(salt));
    expect(await controller.verifyPin('2468'), isTrue);
  });

  test('setupPin stores PBKDF2 hash with random salt and no raw PIN', () async {
    await controller.setupPin('1234');

    expect(controller.state.isPinEnabled, isTrue);
    expect(controller.state.pinHash, startsWith('pbkdf2_sha256\$120000\$'));
    expect(controller.state.pinSalt, hasLength(32));
    expect(storage.settings.pinHash, controller.state.pinHash);
    expect(storage.settings.pinSalt, controller.state.pinSalt);
    expect(storage.settings.toJson().values, isNot(contains('1234')));
    expect(await controller.verifyPin('1234'), isTrue);
  });

  test(
    'three failed attempts lock out and correct PIN is rejected until expiry',
    () async {
      await controller.setupPin('9999');

      expect(await controller.verifyPin('0001'), isFalse);
      expect(await controller.verifyPin('0002'), isFalse);
      expect(await controller.verifyPin('0003'), isFalse);
      expect(controller.state.failedAttempts, 3);
      expect(controller.state.isLockedOut(now), isTrue);
      expect(controller.state.lockoutSecondsRemaining(now), 30);
      expect(await controller.verifyPin('9999'), isFalse);

      controller.setMockNow(now.add(const Duration(seconds: 31)));
      expect(await controller.verifyPin('9999'), isTrue);
      expect(controller.state.failedAttempts, 0);
    },
  );

  test('legacy SHA-256 hash verifies and is upgraded to PBKDF2', () async {
    const pin = '2468';
    const salt = 'legacy_salt';
    final legacyHash = sha256
        .convert(utf8.encode('$salt:$pin:$salt'))
        .toString();
    storage.settings = storage.settings.copyWith(
      pinLockEnabled: true,
      pinHash: legacyHash,
      pinSalt: salt,
    );
    await container.read(settingsProvider.notifier).loadSettings();

    controller.dispose();
    controller = PinSecurityController(
      storage,
      container.read(settingsProvider.notifier),
    );
    controller.setMockNow(now);

    expect(await controller.verifyPin(pin), isTrue);
    await pumpEventQueue();

    expect(storage.settings.pinHash, startsWith('pbkdf2_sha256\$'));
    expect(storage.settings.pinHash, isNot(legacyHash));
    expect(await controller.verifyPin(pin), isTrue);
  });

  test('disabling PIN clears hash, salt, strict mode, and lockout', () async {
    await controller.setupPin('1357');
    await controller.setStrictMode(true);

    await controller.disablePin('0000');
    expect(controller.state.isPinEnabled, isTrue);

    await controller.disablePin('1357');
    expect(controller.state.isPinEnabled, isFalse);
    expect(controller.state.pinHash, isNull);
    expect(storage.settings.pinLockEnabled, isFalse);
    expect(storage.settings.pinHash, isNull);
    expect(storage.settings.pinSalt, isNull);
    expect(storage.settings.strictModeEnabled, isFalse);
  });
  test('missing PIN hash fails closed when PIN flag is set', () async {
    storage.settings = storage.settings.copyWith(
      pinLockEnabled: true,
      pinHash: null,
      pinSalt: null,
    );
    await container.read(settingsProvider.notifier).loadSettings();

    controller.dispose();
    controller = PinSecurityController(
      storage,
      container.read(settingsProvider.notifier),
    );
    controller.setMockNow(now);

    expect(controller.state.isPinEnabled, isTrue);
    expect(await controller.verifyPin('0000'), isFalse);
    expect(await controller.verifyPin('1234'), isFalse);
  });
}
