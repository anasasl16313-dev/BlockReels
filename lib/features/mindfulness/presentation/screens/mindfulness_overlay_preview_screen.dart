import 'package:flutter/material.dart';

import '../controllers/mindfulness_controller.dart';
import '../widgets/breathing_circle_widget.dart';
import '../widgets/hold_to_unlock_button.dart';
import '../widgets/intention_selector_chips.dart';

/// Screen displaying the mindfulness breathing intervention and hold friction.
class MindfulnessOverlayPreviewScreen extends StatelessWidget {
  final MindfulnessController controller;

  const MindfulnessOverlayPreviewScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;

        return Scaffold(
          backgroundColor: Colors.black87,
          body: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Text(
                    'MINDFUL PAUSE',
                    style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    state.currentQuote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  BreathingCircleWidget(
                    phase: state.breathingPhase,
                    secondsRemaining: state.breathingSecondsRemaining,
                  ),
                  IntentionSelectorChips(
                    selectedIntention: state.selectedIntention,
                    onSelected: controller.selectIntention,
                  ),
                  HoldToUnlockButton(
                    progress: state.holdProgress,
                    isHolding: state.isHolding,
                    isUnlocked: state.isUnlocked,
                    durationSeconds: state.holdDurationSeconds,
                    onStartHold: controller.startHold,
                    onCancelHold: controller.cancelHold,
                  ),
                  ElevatedButton(
                    key: const Key('btn_leave_app'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    onPressed: controller.leaveApp,
                    child: const Text('Leave App & Stay Focused'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
