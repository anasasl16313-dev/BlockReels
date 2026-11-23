import 'package:flutter/material.dart';

import '../../domain/models/breathing_phase.dart';

/// Animated circle widget displaying the current breathing phase and countdown timer.
class BreathingCircleWidget extends StatelessWidget {
  final BreathingPhase phase;
  final int secondsRemaining;

  const BreathingCircleWidget({
    super.key,
    required this.phase,
    required this.secondsRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final phaseName = phase == BreathingPhase.inhale
        ? 'Inhale'
        : phase == BreathingPhase.hold
            ? 'Hold'
            : 'Exhale';

    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.tealAccent, width: 4),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              phaseName,
              key: const Key('breathing_phase_text'),
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '(${secondsRemaining}s)',
              key: const Key('breathing_seconds_text'),
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
