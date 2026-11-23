import 'package:block_reels/core/models/rule_model.dart';
import 'package:block_reels/core/theme/app_theme.dart';
import 'package:block_reels/features/app_blocker/presentation/controllers/app_blocker_controller.dart';
import 'package:block_reels/features/app_blocker/presentation/widgets/app_target_card.dart';
import 'package:block_reels/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:block_reels/features/dashboard/presentation/widgets/service_status_card.dart';
import 'package:block_reels/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:block_reels/features/onboarding/presentation/widgets/accessibility_step_view.dart';
import 'package:block_reels/features/settings/presentation/widgets/zero_network_privacy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final themes = {
    'light': AppTheme.lightTheme,
    'dark': AppTheme.darkTheme,
    'amoled': AppTheme.amoledTheme,
  };

  late FakeStorageRepository storage;
  late FakePlatformBridge bridge;
  late DashboardController dashboardController;
  late OnboardingController onboardingController;
  late AppBlockerController blockerController;

  setUp(() async {
    storage = FakeStorageRepository();
    await storage.saveRule(RuleModel(
      id: 'instagram',
      packageName: 'com.instagram.android',
      appName: 'Instagram',
    ));
    bridge = FakePlatformBridge();
    dashboardController = DashboardController(bridge, storage: storage);
    onboardingController = OnboardingController(bridge, storage: storage);
    blockerController = AppBlockerController(bridge, storage: storage);
    await pumpEventQueue();
  });

  tearDown(() async {
    dashboardController.dispose();
    onboardingController.dispose();
    blockerController.dispose();
    await bridge.dispose();
  });

  testWidgets('service and privacy cards use paired semantic colors',
      (tester) async {
    for (final entry in themes.entries) {
      final statusColors = entry.value.extension<StatusThemeExtension>()!;

      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ServiceStatusCard(controller: dashboardController),
                const SizedBox(height: 16),
                const ZeroNetworkPrivacyCard(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final serviceCard = tester.widget<Card>(
        find.byKey(const Key('card_service_status')),
      );
      final serviceTitle = tester.widget<Text>(
        find.byKey(const Key('service_status_title')),
      );
      final privacyCard = tester.widget<Card>(
        find.byKey(const Key('card_zero_network_trust')),
      );
      final privacyTitle = tester.widget<Text>(
        find.text('100% On-Device Privacy'),
      );

      expect(serviceCard.color, statusColors.success.container,
          reason: entry.key);
      expect(serviceTitle.style?.color, statusColors.success.foreground,
          reason: entry.key);
      expect(find.byIcon(Icons.shield), findsOneWidget, reason: entry.key);
      expect(privacyCard.color, statusColors.info.container, reason: entry.key);
      expect(privacyTitle.style?.color, statusColors.info.foreground,
          reason: entry.key);
      expect(find.byIcon(Icons.security), findsOneWidget, reason: entry.key);
    }

    bridge.emitServiceStatus(false);
    await tester.runAsync(pumpEventQueue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.amoledTheme,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: ServiceStatusCard(controller: dashboardController),
        ),
      ),
    );
    await tester.pump();

    final statusColors =
        Theme.of(tester.element(find.byType(ServiceStatusCard)))
            .extension<StatusThemeExtension>()!;
    final inactiveCard = tester.widget<Card>(
      find.byKey(const Key('card_service_status')),
    );
    expect(inactiveCard.color, statusColors.error.container);
    expect(find.text('Setup required'), findsOneWidget);
    expect(find.byIcon(Icons.gpp_bad_outlined), findsOneWidget);
    expect(find.byKey(const Key('btn_protection_action')), findsOneWidget);
  });

  testWidgets('permission state is explicit and themed in every mode',
      (tester) async {
    onboardingController.state = onboardingController.state.copyWith(
      isAccessibilityGranted: false,
    );

    for (final entry in themes.entries) {
      final statusColors = entry.value.extension<StatusThemeExtension>()!;
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: AccessibilityStepView(controller: onboardingController),
            ),
          ),
        ),
      );
      await tester.pump();

      final statusContainer = tester.widget<Container>(
        find.byKey(const Key('accessibility_status_container')),
      );
      final decoration = statusContainer.decoration! as BoxDecoration;
      final statusText = tester.widget<Text>(
        find.byKey(const Key('accessibility_status_text')),
      );
      expect(decoration.color, statusColors.warning.container,
          reason: entry.key);
      expect(statusText.style?.color, statusColors.warning.foreground,
          reason: entry.key);
      expect(find.textContaining('Permission required'), findsOneWidget,
          reason: entry.key);
      expect(find.byIcon(Icons.warning), findsOneWidget, reason: entry.key);
    }

    onboardingController.state = onboardingController.state.copyWith(
      isAccessibilityGranted: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.amoledTheme,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: AccessibilityStepView(controller: onboardingController),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Permission granted'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('app target distinguishes protected, paused, and off states',
      (tester) async {
    final packageName = blockerController.state.appConfigs.keys.first;
    var config = blockerController.state.appConfigs[packageName]!;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: AppTargetCard(
            config: config,
            controller: blockerController,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Selected · manual blocking is on'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    await blockerController.setMasterToggle(false);
    config = blockerController.state.appConfigs[packageName]!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: AppTargetCard(
            config: config,
            controller: blockerController,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Selected · master protection is off'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
    expect(
      tester.widget<Switch>(find.byType(Switch)).onChanged,
      isNull,
    );

    await blockerController.setMasterToggle(true);
    await blockerController.toggleApp(packageName, false);
    config = blockerController.state.appConfigs[packageName]!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        themeAnimationDuration: Duration.zero,
        home: Scaffold(
          body: AppTargetCard(
            config: config,
            controller: blockerController,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Not selected for manual blocking'), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
  });
}
