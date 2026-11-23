import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';

/// Welcome step introducing BlockReels value proposition and privacy guarantee.
class WelcomeStepView extends StatelessWidget {
  final OnboardingController controller;

  const WelcomeStepView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome to BlockReels',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Surgically block addictive Reels & Shorts while keeping DMs, profiles, and feeds intact.',
        ),
        const SizedBox(height: 32),
        const Text('🔒 100% Offline • Zero Tracking • Zero Account Required'),
        const SizedBox(height: 16),
        ElevatedButton(
          key: const Key('btn_get_started'),
          onPressed: controller.nextStep,
          child: const Text('Get Started'),
        ),
      ],
    );
  }
}
