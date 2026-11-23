import 'onboarding_step.dart';

/// Immutable state container for the interactive onboarding wizard flow.
class OnboardingState {
  final OnboardingStep currentStep;
  final int stepIndex;
  final bool isAccessibilityGranted;
  final bool isBatteryOptIgnored;
  final Map<String, bool> selectedApps;
  final String selectedInterventionMode;
  final int holdDurationSeconds;
  final bool isOnboardingCompleted;
  final bool isBusy;
  final String? errorMessage;

  const OnboardingState({
    this.currentStep = OnboardingStep.welcome,
    this.stepIndex = 0,
    this.isAccessibilityGranted = false,
    this.isBatteryOptIgnored = false,
    this.selectedApps = const {
      'com.instagram.android': true,
      'com.google.android.youtube': true,
      'com.facebook.katana': false,
      'com.zhiliaoapp.musically': true,
    },
    this.selectedInterventionMode = 'MINDFUL_PAUSE',
    this.holdDurationSeconds = 10,
    this.isOnboardingCompleted = false,
    this.isBusy = false,
    this.errorMessage,
  });

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    int? stepIndex,
    bool? isAccessibilityGranted,
    bool? isBatteryOptIgnored,
    Map<String, bool>? selectedApps,
    String? selectedInterventionMode,
    int? holdDurationSeconds,
    bool? isOnboardingCompleted,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      stepIndex: stepIndex ?? this.stepIndex,
      isAccessibilityGranted:
          isAccessibilityGranted ?? this.isAccessibilityGranted,
      isBatteryOptIgnored: isBatteryOptIgnored ?? this.isBatteryOptIgnored,
      selectedApps: selectedApps ?? this.selectedApps,
      selectedInterventionMode:
          selectedInterventionMode ?? this.selectedInterventionMode,
      holdDurationSeconds: holdDurationSeconds ?? this.holdDurationSeconds,
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingState &&
          runtimeType == other.runtimeType &&
          currentStep == other.currentStep &&
          stepIndex == other.stepIndex &&
          isAccessibilityGranted == other.isAccessibilityGranted &&
          isBatteryOptIgnored == other.isBatteryOptIgnored &&
          selectedInterventionMode == other.selectedInterventionMode &&
          holdDurationSeconds == other.holdDurationSeconds &&
          isOnboardingCompleted == other.isOnboardingCompleted;

  @override
  int get hashCode =>
      currentStep.hashCode ^
      stepIndex.hashCode ^
      isAccessibilityGranted.hashCode ^
      isBatteryOptIgnored.hashCode ^
      selectedInterventionMode.hashCode ^
      holdDurationSeconds.hashCode ^
      isOnboardingCompleted.hashCode;
}
