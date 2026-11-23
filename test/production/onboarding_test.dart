import 'package:block_reels/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

class _FailingBridge extends FakePlatformBridge {
  @override
  Future<bool> syncAppToggles(Map<String, bool> toggles) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeStorageRepository storage;
  late FakePlatformBridge bridge;
  late OnboardingController controller;

  setUp(() async {
    storage = FakeStorageRepository();
    bridge = FakePlatformBridge();
    controller = OnboardingController(bridge, storage: storage);
    await pumpEventQueue();
  });

  tearDown(() async {
    controller.dispose();
    await bridge.dispose();
  });

  test('hydrates permission and app selection state from production services',
      () {
    expect(controller.state.isAccessibilityGranted, isTrue);
    expect(controller.state.isBatteryOptIgnored, isTrue);
    expect(controller.state.selectedApps, isNotEmpty);
  });

  test('step navigation uses the onboarding enum and stops at last step', () {
    expect(controller.state.currentStep, OnboardingStep.welcome);
    controller.nextStep();
    expect(
        controller.state.currentStep, OnboardingStep.accessibilityPermission);
    controller.previousStep();
    expect(controller.state.currentStep, OnboardingStep.welcome);
  });

  test('completion persists rules, settings, and bridge configuration',
      () async {
    controller.toggleAppSelection('com.facebook.katana', true);
    await controller.completeOnboarding();

    expect(storage.rules, hasLength(4));
    expect(storage.rules['com.facebook.katana']!.isEnabled, isTrue);
    expect(storage.settings.isOnboardingCompleted, isTrue);
    expect(controller.state.isOnboardingCompleted, isTrue);
    expect(controller.state.currentStep, OnboardingStep.completed);

    expect(bridge.syncRulesCalls, isNotEmpty);
    expect(bridge.syncAppTogglesCalls, isNotEmpty);
    expect(bridge.syncConfigCalls, isNotEmpty);
    expect(bridge.updateSettingsCalls, isNotEmpty);
    expect(
      bridge.updateSettingsCalls.last.isOnboardingCompleted,
      isTrue,
    );
  });

  test('denied Accessibility remains unready and can be deferred', () async {
    bridge.serviceEnabled = false;
    await controller.requestAccessibility();
    await controller.listenToServiceState();
    expect(controller.state.isAccessibilityGranted, isFalse);
    expect(await controller.completeOnboarding(), isTrue);
    expect(controller.state.isAccessibilityGranted, isFalse);
  });

  test('no selected apps cannot finish', () async {
    for (final app in controller.state.selectedApps.keys.toList()) {
      controller.toggleAppSelection(app, false);
    }
    expect(await controller.completeOnboarding(), isFalse);
    expect(storage.settings.isOnboardingCompleted, isFalse);
  });

  test('sync failure leaves completion unset and permits retry', () async {
    final failed = _FailingBridge();
    final flow = OnboardingController(failed, storage: storage);
    await pumpEventQueue();
    expect(await flow.completeOnboarding(), isFalse);
    expect(storage.settings.isOnboardingCompleted, isFalse);
    expect(flow.state.errorMessage, isNotNull);
    flow.dispose();
    await failed.dispose();
    expect(await controller.completeOnboarding(), isTrue);
    expect(await controller.completeOnboarding(), isFalse);
  });

  testWidgets('return from system settings checks permission again',
      (tester) async {
    bridge.serviceEnabled = false;
    await controller.listenToServiceState();
    controller.nextStep();
    await tester.pumpWidget(MaterialApp(
      home: OnboardingWizardScreen(controller: controller),
    ));
    expect(find.text('Permission required — protection is not active'),
        findsOneWidget);
    bridge.serviceEnabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.state.isAccessibilityGranted, isTrue);
    expect(find.text('Permission granted — protection can run'),
        findsOneWidget);
  });
}
