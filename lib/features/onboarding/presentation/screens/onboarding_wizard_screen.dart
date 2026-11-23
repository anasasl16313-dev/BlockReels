import 'package:flutter/material.dart';

import '../controllers/onboarding_controller.dart';
import '../widgets/accessibility_step_view.dart';
import '../widgets/battery_step_view.dart';
import '../widgets/target_apps_step_view.dart';
import '../widgets/welcome_step_view.dart';

/// Interactive multi-step onboarding wizard screen for initial setup.
class OnboardingWizardScreen extends StatefulWidget {
  final OnboardingController controller;
  final VoidCallback? onFinished;

  const OnboardingWizardScreen({
    super.key,
    required this.controller,
    this.onFinished,
  });

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.listenToServiceState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Scaffold(
          appBar: AppBar(
            title: Text('Step ${state.stepIndex + 1} of 4'),
            leading: state.stepIndex > 0
                ? IconButton(
                    key: const Key('onboarding_back_button'),
                    tooltip: 'Previous setup step',
                    icon: const Icon(Icons.arrow_back),
                    onPressed:
                        state.isBusy ? null : widget.controller.previousStep,
                  )
                : null,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                if (state.errorMessage != null)
                  Text(state.errorMessage!,
                      key: const Key('onboarding_error'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                _buildCurrentStep(context, state.stepIndex),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStep(BuildContext context, int stepIndex) {
    switch (stepIndex) {
      case 0:
        return WelcomeStepView(controller: widget.controller);
      case 1:
        return AccessibilityStepView(controller: widget.controller);
      case 2:
        return BatteryStepView(controller: widget.controller);
      case 3:
      default:
        return TargetAppsStepView(
          controller: widget.controller,
          onFinished: widget.onFinished,
        );
    }
  }
}
