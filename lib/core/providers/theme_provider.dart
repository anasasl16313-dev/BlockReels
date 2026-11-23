import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// StateNotifier controlling the active visual theme mode ('system', 'light', 'dark', 'amoled').
class ThemeModeNotifier extends StateNotifier<String> {
  final Ref _ref;

  ThemeModeNotifier(this._ref) : super('system') {
    _init();
  }

  void _init() {
    final currentSettings = _ref.read(settingsProvider);
    state = currentSettings.themeMode;
  }

  Future<void> setThemeMode(String mode) async {
    state = mode;
    await _ref.read(settingsProvider.notifier).setThemeMode(mode);
  }
}

/// Provider exposing the active theme mode string.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, String>((ref) {
  return ThemeModeNotifier(ref);
});
