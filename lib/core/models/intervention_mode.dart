/// Defines the intervention strategies deployed when short-form video feeds are intercepted.
enum InterventionMode {
  /// Instantly triggers Android System Back navigation to exit the feed immediately.
  immediateBack,

  /// Displays a calming mindfulness breathing screen with hold-to-unlock friction.
  mindfulPause,

  /// Exits the feed without an unlock action in the overlay.
  strictBlock;

  String get displayName {
    switch (this) {
      case InterventionMode.immediateBack:
        return 'Leave feed';
      case InterventionMode.mindfulPause:
        return 'Pause and hold';
      case InterventionMode.strictBlock:
        return 'Block feed';
    }
  }

  String get description {
    switch (this) {
      case InterventionMode.immediateBack:
        return 'Leaves the short-video feed immediately.';
      case InterventionMode.mindfulPause:
        return 'Hold for the chosen duration to get temporary access.';
      case InterventionMode.strictBlock:
        return 'Leaves the feed with no unlock button. The PIN protects settings changes.';
    }
  }

  /// Parses a string into an [InterventionMode], supporting various wire protocol formats.
  static InterventionMode fromString(String? value) {
    if (value == null) return InterventionMode.immediateBack;
    final normalized = value.trim().toLowerCase().replaceAll('_', '');
    switch (normalized) {
      case 'mindfulpause':
      case 'mindful':
        return InterventionMode.mindfulPause;
      case 'strictblock':
      case 'strict':
        return InterventionMode.strictBlock;
      case 'immediateback':
      case 'autoback':
      case 'back':
      default:
        return InterventionMode.immediateBack;
    }
  }

  String toJson() => name;

  @override
  String toString() => name;
}
