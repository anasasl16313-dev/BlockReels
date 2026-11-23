import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/features/dashboard/dashboard.dart';
import 'package:block_reels/features/onboarding/onboarding.dart';
import 'package:block_reels/features/settings/presentation/widgets/zero_network_privacy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

class _PermissionBridge extends FakePlatformBridge {
  int accessibilityRequests = 0;
  @override
  Future<bool> requestAccessibilityPermission() async {
    accessibilityRequests++;
    return true;
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(pumpEventQueue);
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
}

void main() {
  late _PermissionBridge bridge;
  late FakeStorageRepository storage;

  setUp(() async {
    bridge = _PermissionBridge()..serviceEnabled = false;
    storage = FakeStorageRepository();
    await storage.saveRule(RuleModel(
        id: 'instagram',
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        isEnabled: true));
  });
  tearDown(() async {
    await bridge.dispose();
  });

  Future<Finder> pumpEntry(WidgetTester tester, String entry) async {
    if (entry == 'onboarding') {
      final controller = OnboardingController(bridge, storage: storage);
      addTearDown(controller.dispose);
      await tester.runAsync(pumpEventQueue);
      controller.nextStep();
      await tester.pumpWidget(
          MaterialApp(home: OnboardingWizardScreen(controller: controller)));
      await _settle(tester);
      return find.byKey(const Key('btn_open_accessibility'));
    }
    final controller = DashboardController(bridge, storage: storage);
    addTearDown(controller.dispose);
    await tester.runAsync(controller.refresh);
    await tester
        .pumpWidget(MaterialApp(home: DashboardScreen(controller: controller)));
    await _settle(tester);
    return find.byKey(Key(entry == 'dashboard status'
        ? 'btn_protection_action'
        : 'btn_empty_accessibility_setup'));
  }

  for (final entry in [
    'onboarding',
    'dashboard status',
    'dashboard empty state'
  ]) {
    for (final accept in [false, true]) {
      testWidgets(
          '$entry ${accept ? 'accepts' : 'cancels'} the same offline disclosure before settings',
          (tester) async {
        final button = await pumpEntry(tester, entry);
        await tester.ensureVisible(button);
        await _settle(tester);
        await tester.tap(button);
        await _settle(tester);
        expect(find.byKey(const Key('accessibility_privacy_dialog')),
            findsOneWidget);
        expect(find.text('Accessibility access & privacy'), findsOneWidget);
        expect(find.textContaining('text and accessibility descriptions'),
            findsOneWidget);
        expect(find.textContaining('BlockReels transmits none of this data'),
            findsOneWidget);
        expect(bridge.accessibilityRequests, 0);
        await tester.tap(find.byKey(Key(accept
            ? 'btn_accessibility_consent_accept'
            : 'btn_accessibility_consent_cancel')));
        await _settle(tester);
        expect(find.byKey(const Key('accessibility_privacy_dialog')),
            findsNothing);
        expect(bridge.accessibilityRequests, accept ? 1 : 0);
      });
    }
  }

  testWidgets('system back dismisses disclosure without opening settings',
      (tester) async {
    final button = await pumpEntry(tester, 'onboarding');
    await tester.tap(button);
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byKey(const Key('accessibility_privacy_dialog')), findsNothing);
    expect(bridge.accessibilityRequests, 0);
  });

  testWidgets('privacy policy is readable locally without a permission request',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ZeroNetworkPrivacyCard())));
    await tester.tap(find.byKey(const Key('btn_local_privacy_policy')));
    await _settle(tester);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(
        find.textContaining('Older history may contain detection descriptions'),
        findsOneWidget);
    expect(find.byKey(const Key('btn_accessibility_consent_accept')),
        findsNothing);
    await tester.tap(find.text('Close'));
    await _settle(tester);
    expect(bridge.accessibilityRequests, 0);
    expect(find.byKey(const Key('accessibility_privacy_dialog')), findsNothing);
  });
}
