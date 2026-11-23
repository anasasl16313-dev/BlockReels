/// Strategy options for handling short-form video feed interceptions.
enum InterventionMode {
  autoBack,
  mindfulPause,
  strictBlock,
}

extension InterventionModeExt on InterventionMode {
  String get wireName {
    switch (this) {
      case InterventionMode.autoBack:
        return 'AUTO_BACK';
      case InterventionMode.mindfulPause:
        return 'MINDFUL_PAUSE';
      case InterventionMode.strictBlock:
        return 'STRICT_BLOCK';
    }
  }

  String get displayName {
    switch (this) {
      case InterventionMode.autoBack:
        return 'Leave feed';
      case InterventionMode.mindfulPause:
        return 'Pause and hold';
      case InterventionMode.strictBlock:
        return 'Block feed';
    }
  }
}
