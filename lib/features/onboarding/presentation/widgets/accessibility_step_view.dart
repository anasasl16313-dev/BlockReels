import 'package:flutter/material.dart';

import '../../../../core/privacy/accessibility_disclosure.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/onboarding_controller.dart';

/// Accessibility permission step requesting core accessibility service activation.
class AccessibilityStepView extends StatelessWidget {
  final OnboardingController controller;

  const AccessibilityStepView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final statusColors = StatusThemeExtension.of(context);
    final palette = state.isAccessibilityGranted
        ? statusColors.success
        : statusColors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Accessibility Service Permission',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'BlockReels uses Android Accessibility Service to detect when a Reel or Short video is opened on your screen.',
        ),
        const SizedBox(height: 12),
        const Text(
            'In Android settings, open Installed apps or Downloaded services, choose BlockReels, then turn on Use BlockReels. Return here to check the result.'),
        const SizedBox(height: 16),
        Container(
          key: const Key('accessibility_status_container'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: palette.container,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: palette.accent),
          ),
          child: Row(
            children: [
              Icon(
                state.isAccessibilityGranted
                    ? Icons.check_circle
                    : Icons.warning,
                color: palette.accent,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  state.isAccessibilityGranted
                      ? 'Permission granted — protection can run'
                      : 'Permission required — protection is not active',
                  key: const Key('accessibility_status_text'),
                  style: TextStyle(
                    color: palette.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          key: const Key('btn_open_accessibility'),
          onPressed: state.isBusy
              ? null
              : () => openAccessibilitySettingsWithConsent(
                  context, controller.requestAccessibility),
          child: const Text('Open Accessibility Settings'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('btn_next_step_2'),
          onPressed: state.isBusy ? null : controller.nextStep,
          child: Text(state.isAccessibilityGranted
              ? 'Continue'
              : 'Set up later — protection will be off'),
        ),
      ],
    );
  }
}
