/// Application visual theme modes.
enum AppThemeMode {
  system('System'),
  light('Light'),
  dark('Dark'),
  amoled('AMOLED');

  const AppThemeMode(this.label);

  final String label;
}
