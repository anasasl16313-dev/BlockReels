import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';

/// Battery optimization whitelist step to prevent background termination.
class BatteryStepView extends StatelessWidget {
  final OnboardingController controller;

  const BatteryStepView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Battery Optimization Whitelist',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Optional: removing battery restrictions may help Android keep protection running in the background. Accessibility permission is required for blocking.',
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          key: const Key('btn_disable_battery_opt'),
          onPressed: controller.state.isBusy
              ? null
              : () async {
                  await controller.requestBatteryOptimization();
                },
          child: const Text('Disable Battery Restrictions'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('btn_skip_battery_opt'),
          onPressed: controller.state.isBusy ? null : controller.nextStep,
          child: const Text('Continue without battery exception'),
        ),
      ],
    );
  }
}
