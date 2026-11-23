import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';

/// Target apps selection step during initial onboarding.
class TargetAppsStepView extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback? onFinished;

  const TargetAppsStepView({
    super.key,
    required this.controller,
    this.onFinished,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select Target Platforms',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          key: const Key('checkbox_instagram'),
          title: const Text('Instagram Reels'),
          value: state.selectedApps['com.instagram.android'] ?? false,
          onChanged: (v) => controller.toggleAppSelection(
              'com.instagram.android', v ?? false),
        ),
        CheckboxListTile(
          key: const Key('checkbox_youtube'),
          title: const Text('YouTube Shorts'),
          value: state.selectedApps['com.google.android.youtube'] ?? false,
          onChanged: (v) => controller.toggleAppSelection(
              'com.google.android.youtube', v ?? false),
        ),
        CheckboxListTile(
          key: const Key('checkbox_facebook'),
          title: const Text('Facebook Reels'),
          value: state.selectedApps['com.facebook.katana'] ?? false,
          onChanged: (v) =>
              controller.toggleAppSelection('com.facebook.katana', v ?? false),
        ),
        CheckboxListTile(
          key: const Key('checkbox_tiktok'),
          title: const Text('TikTok Feed'),
          value: state.selectedApps['com.zhiliaoapp.musically'] ?? false,
          onChanged: (v) => controller.toggleAppSelection(
              'com.zhiliaoapp.musically', v ?? false),
        ),
        const SizedBox(height: 16),
        Text(state.selectedApps.values.any((v) => v)
            ? state.isAccessibilityGranted
                ? 'Ready to finish setup.'
                : 'Accessibility is off. Finishing now will open the dashboard with protection not ready.'
            : 'Select at least one app to continue.'),
        const SizedBox(height: 16),
        ElevatedButton(
          key: const Key('btn_start_focusing'),
          onPressed: state.isBusy || !state.selectedApps.values.any((v) => v)
              ? null
              : () async {
                  if (await controller.completeOnboarding()) onFinished?.call();
                },
          child: Text(state.isBusy
              ? 'Saving…'
              : state.isAccessibilityGranted
                  ? 'Start Focusing'
                  : 'Finish setup later'),
        ),
      ],
    );
  }
}
