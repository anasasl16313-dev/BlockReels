import 'package:flutter/material.dart';

/// Friction hold button requiring continuous touch duration before triggering unlock.
class HoldToUnlockButton extends StatelessWidget {
  final double progress;
  final bool isHolding;
  final bool isUnlocked;
  final int durationSeconds;
  final VoidCallback onStartHold;
  final VoidCallback onCancelHold;

  const HoldToUnlockButton({
    super.key,
    required this.progress,
    required this.isHolding,
    required this.isUnlocked,
    required this.durationSeconds,
    required this.onStartHold,
    required this.onCancelHold,
  });

  /// Safe clamping boundaries for hold friction duration
  static const int minDurationSeconds = 3;
  static const int maxDurationSeconds = 30;

  static int clampDuration(int seconds) {
    if (seconds < minDurationSeconds) return minDurationSeconds;
    if (seconds > maxDurationSeconds) return maxDurationSeconds;
    return seconds;
  }

  @override
  Widget build(BuildContext context) {
    final remainingSeconds =
        ((1.0 - progress) * durationSeconds).toStringAsFixed(1);

    return Column(
      children: [
        Listener(
          onPointerDown: (_) => onStartHold(),
          onPointerUp: (_) => onCancelHold(),
          onPointerCancel: (_) => onCancelHold(),
          child: Container(
            key: const Key('hold_to_unlock_button'),
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.grey.shade800,
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    key: const Key('hold_progress_bar'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.tealAccent.shade400,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    isUnlocked
                        ? 'UNLOCKED'
                        : isHolding
                            ? 'HOLDING (${remainingSeconds}s remaining)'
                            : 'HOLD TO UNLOCK (${durationSeconds}s)',
                    key: const Key('hold_button_label'),
                    style: TextStyle(
                      color: progress > 0.5 ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          key: const Key('linear_progress_indicator'),
          value: progress,
          backgroundColor: Colors.grey.shade700,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
        ),
      ],
    );
  }
}
