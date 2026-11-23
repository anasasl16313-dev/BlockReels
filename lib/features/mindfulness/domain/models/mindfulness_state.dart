import 'breathing_phase.dart';

/// State of the mindfulness pause overlay, timer, and hold-to-unlock friction.
class MindfulnessState {
  final BreathingPhase breathingPhase;
  final int breathingSecondsRemaining;
  final double holdProgress; // 0.0 to 1.0
  final bool isHolding;
  final bool isUnlocked;
  final int holdDurationSeconds;
  final String? selectedIntention;
  final String currentQuote;

  const MindfulnessState({
    this.breathingPhase = BreathingPhase.inhale,
    this.breathingSecondsRemaining = 4,
    this.holdProgress = 0.0,
    this.isHolding = false,
    this.isUnlocked = false,
    this.holdDurationSeconds = 10,
    this.selectedIntention,
    this.currentQuote = 'Pause. Is this how you want to spend your time?',
  });

  MindfulnessState copyWith({
    BreathingPhase? breathingPhase,
    int? breathingSecondsRemaining,
    double? holdProgress,
    bool? isHolding,
    bool? isUnlocked,
    int? holdDurationSeconds,
    String? selectedIntention,
    String? currentQuote,
  }) {
    return MindfulnessState(
      breathingPhase: breathingPhase ?? this.breathingPhase,
      breathingSecondsRemaining:
          breathingSecondsRemaining ?? this.breathingSecondsRemaining,
      holdProgress: holdProgress ?? this.holdProgress,
      isHolding: isHolding ?? this.isHolding,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      holdDurationSeconds: holdDurationSeconds ?? this.holdDurationSeconds,
      selectedIntention: selectedIntention ?? this.selectedIntention,
      currentQuote: currentQuote ?? this.currentQuote,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindfulnessState &&
          runtimeType == other.runtimeType &&
          breathingPhase == other.breathingPhase &&
          breathingSecondsRemaining == other.breathingSecondsRemaining &&
          holdProgress == other.holdProgress &&
          isHolding == other.isHolding &&
          isUnlocked == other.isUnlocked &&
          holdDurationSeconds == other.holdDurationSeconds &&
          selectedIntention == other.selectedIntention &&
          currentQuote == other.currentQuote;

  @override
  int get hashCode =>
      breathingPhase.hashCode ^
      breathingSecondsRemaining.hashCode ^
      holdProgress.hashCode ^
      isHolding.hashCode ^
      isUnlocked.hashCode ^
      holdDurationSeconds.hashCode ^
      selectedIntention.hashCode ^
      currentQuote.hashCode;
}
