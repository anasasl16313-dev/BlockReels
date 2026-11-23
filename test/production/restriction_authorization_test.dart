import 'package:block_reels/core/providers/platform_bridge_provider.dart';
import 'package:block_reels/core/providers/settings_provider.dart';
import 'package:block_reels/core/providers/storage_provider.dart';
import 'package:block_reels/features/pin_lock/pin_lock.dart';
import 'package:block_reels/features/schedules/schedules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';
import '../test_helpers/fake_pin_worker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageRepository storage;
  late FakePlatformBridge bridge;
  late ProviderContainer container;
  late PinSecurityController pinController;

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
    pinController = PinSecurityController(
      storage,
      container.read(settingsProvider.notifier),
      FakePinWorker(),
    );
  });

  tearDown(() async {
    pinController.dispose();
    container.dispose();
    await bridge.dispose();
  });

  test('a dialog authorization expires even if the next session verifies the PIN', () async {
    expect(await pinController.setupPin('1234'), isTrue);
    expect(await pinController.setupPin('4321'), isFalse);
    expect(await pinController.verifyPin('1234'), isTrue);
    final authorized = pinController.captureRestrictionAuthorization();
    expect(authorized(), isTrue);
    pinController.invalidateAuthentication();
    expect(authorized(), isFalse);
    expect(await pinController.verifyPin('1234'), isTrue);
    expect(authorized(), isFalse);
    expect(pinController.captureRestrictionAuthorization()(), isTrue);
  });

  testWidgets('a schedule editor opened before locking cannot save in the next session', (tester) async {
    await tester.runAsync(() async {
      await pinController.setupPin('1234');
      await pinController.verifyPin('1234');
    });
    final schedules = SchedulesController(bridge, storage);
    addTearDown(schedules.dispose);
    await tester.pumpWidget(MaterialApp(home: SchedulesScreen(
      controller: schedules,
      pinController: pinController,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create schedule'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('field_schedule_name')), 'Example schedule');
    pinController.invalidateAuthentication();
    await tester.runAsync(() => pinController.verifyPin('1234'));
    await tester.ensureVisible(find.byKey(const Key('btn_save_schedule')));
    await tester.tap(find.byKey(const Key('btn_save_schedule')));
    await tester.pumpAndSettle();
    expect(storage.schedules, isEmpty);
    expect(find.byKey(const Key('btn_save_schedule')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('PIN-only protection still requires authorization',
      (tester) async {
    await tester.runAsync(() => pinController.setupPin('1234'));
    expect(pinController.state.isPinEnabled, isTrue);
    expect(pinController.state.isStrictModeActive, isFalse);

    bool? authorized;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              authorized = await authorizeRestrictionChange(
                context,
                pinController,
              );
            },
            child: const Text('Change restrictions'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Change restrictions'));
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);
    expect(find.byKey(const Key('pin_input_field')), findsOneWidget);
    expect(authorized, isNull);

    await tester.enterText(find.byKey(const Key('pin_input_field')), '1234');
    await tester.tap(find.text('Verify'));
    await tester.runAsync(pumpEventQueue);
    await settlePinUi(tester);

    expect(authorized, isTrue);
  });

  testWidgets('unprotected changes do not prompt', (tester) async {
    bool? authorized;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              authorized = await authorizeRestrictionChange(
                context,
                pinController,
              );
            },
            child: const Text('Change restrictions'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Change restrictions'));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pin_input_field')), findsNothing);
    expect(authorized, isTrue);
  });
}
