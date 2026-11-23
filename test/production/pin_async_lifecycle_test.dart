import 'dart:async';

import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/features/pin_lock/pin_lock.dart';
import 'package:block_reels/features/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_pin_worker.dart';
import '../test_helpers/fake_services.dart';

class _GatedStorage extends FakeStorageRepository {
  Completer<void>? saveGate;
  bool failSave = false;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await saveGate?.future;
    if (failSave) throw StateError('Injected save failure');
    await super.saveSettings(settings);
  }
}

void main() {
  late _GatedStorage storage;
  late FakePlatformBridge bridge;
  late ProviderContainer container;
  late PinSecurityController pin;
  late FakePinWorker worker;
  final now = DateTime(2026, 10, 30);

  setUp(() async {
    storage = _GatedStorage();
    bridge = FakePlatformBridge();
    worker = FakePinWorker();
    container = ProviderContainer(overrides: [
      storageRepositoryProvider.overrideWithValue(storage),
      platformBridgeProvider.overrideWithValue(bridge),
      pinCryptoWorkerProvider.overrideWithValue(worker),
    ]);
    await container.read(settingsProvider.notifier).ready;
    pin = container.read(pinSecurityControllerProvider);
    pin.setMockNow(now);
    expect(await pin.setupPin('1234'), isTrue);
  });

  tearDown(() async {
    container.dispose();
    await bridge.dispose();
  });

  test('pending verification is busy and rejects duplicate submissions',
      () async {
    worker.verificationGate = Completer<void>();
    final pending = pin.verifyPin('1234');
    await pumpEventQueue();
    expect(pin.isBusy, isTrue);
    expect(pin.hasCurrentAuthentication, isFalse);
    expect(await pin.verifyPin('0000'), isFalse);
    expect(worker.verificationCalls, 1);
    expect(pin.state.failedAttempts, 0);
    worker.verificationGate!.complete();
    expect(await pending, isTrue);
    expect(pin.isBusy, isFalse);
    expect(pin.hasCurrentAuthentication, isTrue);
  });

  for (final change in [
    'credentials',
    'strict mode',
    'attempts',
    'background'
  ]) {
    test('pending result is rejected after $change changes', () async {
      worker.verificationGate = Completer<void>();
      final pending = pin.verifyPin('1234');
      await pumpEventQueue();
      final notifier = container.read(settingsProvider.notifier);
      if (change == 'background') {
        pin.invalidateAuthentication();
      } else {
        final current = notifier.currentSettings;
        await notifier.updateSettings(switch (change) {
          'credentials' =>
            current.copyWith(pinHash: 'replacement', pinSalt: 'new'),
          'strict mode' => current.copyWith(strictModeEnabled: true),
          _ => current.copyWith(failedPinAttempts: 2),
        });
      }
      final preserved = storage.settings;
      worker.verificationGate!.complete();
      expect(await pending, isFalse);
      expect(pin.hasCurrentAuthentication, isFalse);
      expect(storage.settings.toJson(), preserved.toJson());
    });
  }

  test('failed attempts await persistence; lockouts survive a new controller',
      () async {
    storage.saveGate = Completer<void>();
    var completed = false;
    final pending = pin.verifyPin('0000').then((value) {
      completed = true;
      return value;
    });
    await pumpEventQueue();
    expect(pin.isBusy, isTrue);
    expect(completed, isFalse);
    expect(storage.settings.failedPinAttempts, 0);
    storage.saveGate!.complete();
    expect(await pending, isFalse);
    storage.saveGate = null;
    expect(storage.settings.failedPinAttempts, 1);
    await pin.verifyPin('0000');
    await pin.verifyPin('0000');
    final restarted = PinSecurityController(storage, null, worker);
    await restarted.ready;
    restarted.setMockNow(now);
    expect(restarted.state.failedAttempts, 3);
    expect(restarted.state.lockoutUntil, now.add(const Duration(seconds: 30)));
    final calls = worker.verificationCalls;
    expect(await restarted.verifyPin('1234'), isFalse);
    expect(worker.verificationCalls, calls);
    restarted.dispose();
    for (var attempt = 4; attempt <= 10; attempt++) {
      pin.setMockNow(
          (pin.state.lockoutUntil ?? now).add(const Duration(seconds: 1)));
      final attemptTime = pin.currentNow;
      await pin.verifyPin('0000');
      expect(storage.settings.failedPinAttempts, attempt);
      expect(
          storage.settings.lockoutUntil,
          attemptTime.add(attempt >= 10
              ? const Duration(minutes: 30)
              : attempt >= 5
                  ? const Duration(minutes: 5)
                  : const Duration(seconds: 30)));
    }
    pin.setMockNow(pin.state.lockoutUntil!.add(const Duration(seconds: 1)));
    expect(await pin.verifyPin('1234'), isTrue);
    expect(storage.settings.failedPinAttempts, 0);
    expect(storage.settings.lockoutUntil, isNull);
  });

  test('a failed security save fails closed and restores published settings',
      () async {
    storage.failSave = true;
    expect(await pin.verifyPin('1234'), isFalse);
    expect(pin.hasCurrentAuthentication, isFalse);
    expect(await pin.verifyPin('0000'), isFalse);
    expect(pin.state.failedAttempts, storage.settings.failedPinAttempts);
    expect(pin.state.isPinEnabled, isTrue);
  });

  test('unrelated preference changes do not invalidate pending verification',
      () async {
    worker.verificationGate = Completer<void>();
    final pending = pin.verifyPin('1234');
    await pumpEventQueue();
    await container.read(settingsProvider.notifier).setThemeMode('dark');
    worker.verificationGate!.complete();
    expect(await pending, isTrue);
    expect(storage.settings.themeMode, 'dark');
  });

  testWidgets(
      'dialog stays responsive while pending and ignores duplicate submit',
      (tester) async {
    worker.verificationGate = Completer<void>();
    var authorized = 0;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => PinEntryDialog(
                        onVerifyPin: pin.verifyPin,
                        isAuthenticationCurrent: () =>
                            pin.hasCurrentAuthentication,
                        onAuthenticated: () {
                          authorized++;
                        })),
                child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await settlePinUi(tester);
    await tester.enterText(find.byKey(const Key('pin_input_field')), '1234');
    await tester.tap(find.byKey(const Key('pin_submit_button')));
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('pin_submit_button')))
            .onPressed,
        isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(worker.verificationCalls, 1);
    expect(authorized, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 350));
    worker.verificationGate!.complete();
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    expect(authorized, 0);
  });

  testWidgets('numpad disables input until verification finishes',
      (tester) async {
    worker.verificationGate = Completer<void>();
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: PinEntryWidget(
            controller: pin,
            onResult: (value) {
              result = value;
            })));
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.byKey(Key('btn_numpad_$digit')));
      await tester.pump();
    }
    await tester.runAsync(pumpEventQueue);
    expect(result, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('btn_numpad_1')))
            .onPressed,
        isNull);
    worker.verificationGate!.complete();
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    expect(result, isTrue);
    expect(worker.verificationCalls, 1);
  });

  testWidgets('setup waits for hashing before reporting success',
      (tester) async {
    expect(await tester.runAsync(() => pin.disablePin('1234')), isTrue);
    worker.hashingGate = Completer<void>();
    var configured = 0;
    await tester.pumpWidget(MaterialApp(
        home: PinSetupScreen(
            controller: pin,
            onPinConfigured: () {
              configured++;
            })));
    for (final digit in ['2', '4', '6', '8', '2', '4', '6', '8']) {
      await tester.tap(find.byKey(Key('btn_setup_numpad_$digit')));
      await tester.pump();
    }
    await tester.runAsync(pumpEventQueue);
    expect(configured, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('btn_setup_numpad_2')))
            .onPressed,
        isNull);
    worker.hashingGate!.complete();
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    expect(configured, 1);
    expect(worker.hashingCalls, 2); // Initial fixture plus this setup.
  });

  testWidgets(
      'duration drag drafts locally, authorizes once, commits or cancels',
      (tester) async {
    final settings =
        SettingsController(storage, container.read(settingsProvider.notifier));
    addTearDown(settings.dispose);
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(controller: settings, pinController: pin)));
    await settlePinUi(tester);
    final saved = settings.settings.defaultHoldDurationSeconds;
    final sliderFinder = find.byKey(const Key('slider_hold_duration'));
    await tester.ensureVisible(sliderFinder);
    await settlePinUi(tester);
    var slider = tester.widget<Slider>(sliderFinder);
    slider.onChangeStart!(saved.toDouble());
    for (final value in [12.0, 16.0, 21.0]) {
      slider.onChanged!(value);
    }
    await tester.pump();
    expect(tester.widget<Slider>(sliderFinder).value, 21);
    expect(storage.settings.defaultHoldDurationSeconds, saved);
    expect(find.byKey(const Key('pin_input_field')), findsNothing);
    slider.onChangeEnd!(21);
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pin_input_field')), '1234');
    await tester.tap(find.text('Verify'));
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    expect(worker.verificationCalls, 1);
    expect(storage.settings.defaultHoldDurationSeconds, 21);
    expect(bridge.syncConfigCalls.last.holdDurationSeconds, 21);
    slider = tester.widget<Slider>(sliderFinder);
    slider.onChangeStart!(21);
    slider.onChanged!(30);
    slider.onChangeEnd!(30);
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    await tester.tap(find.text('Cancel'));
    await settlePinUi(tester);
    expect(worker.verificationCalls, 1);
    expect(storage.settings.defaultHoldDurationSeconds, 21);
    expect(tester.widget<Slider>(sliderFinder).value, 21);
  });

  testWidgets('disabling PIN verifies once and awaits persistence',
      (tester) async {
    final settings =
        SettingsController(storage, container.read(settingsProvider.notifier));
    addTearDown(settings.dispose);
    await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(controller: settings, pinController: pin)));
    await settlePinUi(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('switch_pin_lock')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await settlePinUi(tester);
    await tester.ensureVisible(find.byKey(const Key('switch_pin_lock')));
    await settlePinUi(tester);
    await tester.tap(find.byKey(const Key('switch_pin_lock')));
    await settlePinUi(tester);
    await tester.enterText(find.byKey(const Key('pin_input_field')), '1234');
    await tester.tap(find.text('Verify'));
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    expect(worker.verificationCalls, 1);
    expect(storage.settings.pinLockEnabled, isFalse);
    expect(storage.settings.pinHash, isNull);
    expect(storage.settings.pinSalt, isNull);
    expect(pin.state.isPinEnabled, isFalse);
    expect(find.byKey(const Key('pin_input_field')), findsNothing);
  });
}
