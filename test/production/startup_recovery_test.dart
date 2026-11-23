import 'dart:async';

import 'package:block_reels/app.dart';
import 'package:block_reels/core/models/app_settings.dart';
import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

class FailingStartupStorage extends FakeStorageRepository {
  bool failInitialization = false;
  bool failSettingsRead = false;
  int initializationCalls = 0;
  int settingsReads = 0;
  Completer<void>? initializationGate;

  @override
  Future<void> init({String? customPath}) async {
    initializationCalls++;
    await initializationGate?.future;
    if (failInitialization)
      throw StateError('Temporary initialization failure');
  }

  @override
  Future<AppSettings> getSettings() async {
    settingsReads++;
    if (failSettingsRead) throw StateError('Temporary settings failure');
    return super.getSettings();
  }
}

void main() {
  late FailingStartupStorage storage;
  late FakePlatformBridge bridge;

  setUp(() {
    storage = FailingStartupStorage();
    storage.settings = AppSettings(
      pinLockEnabled: true,
      strictModeEnabled: true,
      pinHash: 'saved_hash',
      pinSalt: 'saved_salt',
      failedPinAttempts: 3,
      isForegroundServiceEnabled: true,
    );
    bridge = FakePlatformBridge();
  });

  tearDown(() async {
    await bridge.dispose();
  });

  testWidgets('startup follows the device until the saved theme loads',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    storage.settings = storage.settings.copyWith(themeMode: 'light');
    final gate = Completer<void>();
    storage.initializationGate = gate;

    await tester.pumpWidget(AppStartup(
      storageRepository: storage,
      platformBridge: bridge,
    ));
    final loading = tester.element(find.byType(CircularProgressIndicator));
    expect(Theme.of(loading).brightness, Brightness.dark);

    gate.complete();
    await tester.pumpAndSettle();
    final shell = tester.element(find.byKey(const Key('app_main_shell')));
    expect(Theme.of(shell).brightness, Brightness.light);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup failures show retry before application providers start',
      (tester) async {
    storage.failInitialization = true;
    await tester.pumpWidget(AppStartup(
      storageRepository: storage,
      platformBridge: bridge,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Could not open your saved data. Please try again.'),
        findsOneWidget);
    expect(find.byKey(const Key('app_onboarding_gate')), findsNothing);
    expect(storage.initializationCalls, 1);
    expect(storage.settingsReads, 0);
    expect(bridge.syncConfigCalls, isEmpty);
    expect(bridge.syncRulesCalls, isEmpty);
    expect(bridge.foregroundRunning, isFalse);

    final retryGate = Completer<void>();
    storage.initializationGate = retryGate;
    await tester.tap(find.byKey(const Key('startup_retry')));
    await tester.pump();
    expect(find.byKey(const Key('startup_retry')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(storage.initializationCalls, 2);
    retryGate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup_retry')), findsOneWidget);
    expect(tester.takeException(), isNull);

    storage.failInitialization = false;
    storage.failSettingsRead = true;
    await tester.tap(find.byKey(const Key('startup_retry')));
    await tester.pumpAndSettle();
    expect(storage.initializationCalls, 3);
    expect(storage.settingsReads, 1);
    expect(find.byKey(const Key('app_onboarding_gate')), findsNothing);
    expect(bridge.foregroundRunning, isFalse);
    expect(bridge.syncConfigCalls, isEmpty);
    expect(storage.settings.pinLockEnabled, isTrue);

    storage.failSettingsRead = false;
    await tester.tap(find.byKey(const Key('startup_retry')));
    await tester.pumpAndSettle();
    expect(storage.initializationCalls, 4);
    expect(find.byKey(const Key('startup_retry')), findsNothing);
    expect(find.byKey(const Key('app_onboarding_gate')), findsNothing);
    expect(find.byKey(const Key('app_main_shell')), findsOneWidget);
    expect(bridge.foregroundRunning, isTrue);
    expect(storage.settings.pinHash, 'saved_hash');
    expect(storage.settings.failedPinAttempts, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('bootstrap settings read failure does not become onboarding',
      (tester) async {
    storage.failSettingsRead = true;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageRepositoryProvider.overrideWithValue(storage),
        platformBridgeProvider.overrideWithValue(bridge),
      ],
      child: const MaterialApp(home: AppBootstrapGate()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup_retry')), findsOneWidget);
    expect(find.byKey(const Key('app_onboarding_gate')), findsNothing);
    expect(find.byKey(const Key('app_main_shell')), findsNothing);
    expect(storage.settings.pinLockEnabled, isTrue);

    storage.failSettingsRead = false;
    await tester.tap(find.byKey(const Key('startup_retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup_retry')), findsNothing);
    expect(find.byKey(const Key('app_onboarding_gate')), findsNothing);
    expect(find.byKey(const Key('app_main_shell')), findsOneWidget);
    expect(storage.settings.pinHash, 'saved_hash');
    expect(storage.settings.pinLockEnabled, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
