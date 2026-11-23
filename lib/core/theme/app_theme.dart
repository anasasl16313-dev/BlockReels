import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_layout.dart';
import 'app_text_styles.dart';

@immutable
class SemanticColorSet {
  final Color container;
  final Color foreground;
  final Color accent;

  const SemanticColorSet({
    required this.container,
    required this.foreground,
    required this.accent,
  });

  static SemanticColorSet lerp(
    SemanticColorSet first,
    SemanticColorSet second,
    double t,
  ) {
    return SemanticColorSet(
      container: Color.lerp(first.container, second.container, t)!,
      foreground: Color.lerp(first.foreground, second.foreground, t)!,
      accent: Color.lerp(first.accent, second.accent, t)!,
    );
  }
}

/// Accessible container/text/icon sets for non-neutral application states.
@immutable
class StatusThemeExtension extends ThemeExtension<StatusThemeExtension> {
  final SemanticColorSet success;
  final SemanticColorSet warning;
  final SemanticColorSet error;
  final SemanticColorSet info;

  const StatusThemeExtension({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  /// Uses the configured BlockReels palette, with a Material semantic fallback
  /// for isolated widgets hosted under another [ThemeData].
  static StatusThemeExtension of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<StatusThemeExtension>() ??
        StatusThemeExtension.fromColorScheme(theme.colorScheme);
  }

  factory StatusThemeExtension.fromColorScheme(ColorScheme colors) {
    return StatusThemeExtension(
      success: SemanticColorSet(
        container: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
        accent: colors.primary,
      ),
      warning: SemanticColorSet(
        container: colors.tertiaryContainer,
        foreground: colors.onTertiaryContainer,
        accent: colors.tertiary,
      ),
      error: SemanticColorSet(
        container: colors.errorContainer,
        foreground: colors.onErrorContainer,
        accent: colors.error,
      ),
      info: SemanticColorSet(
        container: colors.secondaryContainer,
        foreground: colors.onSecondaryContainer,
        accent: colors.secondary,
      ),
    );
  }

  @override
  StatusThemeExtension copyWith({
    SemanticColorSet? success,
    SemanticColorSet? warning,
    SemanticColorSet? error,
    SemanticColorSet? info,
  }) {
    return StatusThemeExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
    );
  }

  @override
  StatusThemeExtension lerp(
    covariant StatusThemeExtension? other,
    double t,
  ) {
    if (other == null) return this;
    return StatusThemeExtension(
      success: SemanticColorSet.lerp(success, other.success, t),
      warning: SemanticColorSet.lerp(warning, other.warning, t),
      error: SemanticColorSet.lerp(error, other.error, t),
      info: SemanticColorSet.lerp(info, other.info, t),
    );
  }
}

/// Custom theme extension delivering specialized colors for mindfulness breathing and focus metrics.
@immutable
class FocusThemeExtension extends ThemeExtension<FocusThemeExtension> {
  final Color calmContainer;
  final Color alertContainer;
  final Color streakColor;
  final Color timeSavedGlow;
  final Color breathingRingColor;
  final Color frictionTrackColor;

  const FocusThemeExtension({
    required this.calmContainer,
    required this.alertContainer,
    required this.streakColor,
    required this.timeSavedGlow,
    required this.breathingRingColor,
    required this.frictionTrackColor,
  });

  static FocusThemeExtension of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return theme.extension<FocusThemeExtension>() ??
        FocusThemeExtension(
          calmContainer: colors.primaryContainer,
          alertContainer: colors.errorContainer,
          streakColor: colors.tertiary,
          timeSavedGlow: colors.primary,
          breathingRingColor: colors.primary,
          frictionTrackColor: colors.outline,
        );
  }

  @override
  FocusThemeExtension copyWith({
    Color? calmContainer,
    Color? alertContainer,
    Color? streakColor,
    Color? timeSavedGlow,
    Color? breathingRingColor,
    Color? frictionTrackColor,
  }) {
    return FocusThemeExtension(
      calmContainer: calmContainer ?? this.calmContainer,
      alertContainer: alertContainer ?? this.alertContainer,
      streakColor: streakColor ?? this.streakColor,
      timeSavedGlow: timeSavedGlow ?? this.timeSavedGlow,
      breathingRingColor: breathingRingColor ?? this.breathingRingColor,
      frictionTrackColor: frictionTrackColor ?? this.frictionTrackColor,
    );
  }

  @override
  FocusThemeExtension lerp(
      ThemeExtension<FocusThemeExtension>? other, double t) {
    if (other is! FocusThemeExtension) return this;
    return FocusThemeExtension(
      calmContainer: Color.lerp(calmContainer, other.calmContainer, t)!,
      alertContainer: Color.lerp(alertContainer, other.alertContainer, t)!,
      streakColor: Color.lerp(streakColor, other.streakColor, t)!,
      timeSavedGlow: Color.lerp(timeSavedGlow, other.timeSavedGlow, t)!,
      breathingRingColor:
          Color.lerp(breathingRingColor, other.breathingRingColor, t)!,
      frictionTrackColor:
          Color.lerp(frictionTrackColor, other.frictionTrackColor, t)!,
    );
  }
}

/// Material 3 theme configurations supporting Light, Dark, and AMOLED Black modes.
class AppTheme {
  AppTheme._();

  static const _lightStatusColors = StatusThemeExtension(
    success: SemanticColorSet(
      container: AppColors.lightSuccessContainer,
      foreground: AppColors.lightOnSuccessContainer,
      accent: AppColors.lightSuccessAccent,
    ),
    warning: SemanticColorSet(
      container: AppColors.lightWarningContainer,
      foreground: AppColors.lightOnWarningContainer,
      accent: AppColors.lightWarningAccent,
    ),
    error: SemanticColorSet(
      container: AppColors.lightErrorContainer,
      foreground: AppColors.lightOnErrorContainer,
      accent: AppColors.lightErrorAccent,
    ),
    info: SemanticColorSet(
      container: AppColors.lightInfoContainer,
      foreground: AppColors.lightOnInfoContainer,
      accent: AppColors.lightInfoAccent,
    ),
  );

  static const _darkStatusColors = StatusThemeExtension(
    success: SemanticColorSet(
      container: AppColors.darkSuccessContainer,
      foreground: AppColors.darkOnSuccessContainer,
      accent: AppColors.darkSuccessAccent,
    ),
    warning: SemanticColorSet(
      container: AppColors.darkWarningContainer,
      foreground: AppColors.darkOnWarningContainer,
      accent: AppColors.darkWarningAccent,
    ),
    error: SemanticColorSet(
      container: AppColors.darkErrorContainer,
      foreground: AppColors.darkOnErrorContainer,
      accent: AppColors.darkErrorAccent,
    ),
    info: SemanticColorSet(
      container: AppColors.darkInfoContainer,
      foreground: AppColors.darkOnInfoContainer,
      accent: AppColors.darkInfoAccent,
    ),
  );

  static const _amoledStatusColors = StatusThemeExtension(
    success: SemanticColorSet(
      container: AppColors.amoledSuccessContainer,
      foreground: AppColors.darkOnSuccessContainer,
      accent: AppColors.darkSuccessAccent,
    ),
    warning: SemanticColorSet(
      container: AppColors.amoledWarningContainer,
      foreground: AppColors.darkOnWarningContainer,
      accent: AppColors.darkWarningAccent,
    ),
    error: SemanticColorSet(
      container: AppColors.amoledErrorContainer,
      foreground: AppColors.darkOnErrorContainer,
      accent: AppColors.darkErrorAccent,
    ),
    info: SemanticColorSet(
      container: AppColors.amoledInfoContainer,
      foreground: AppColors.darkOnInfoContainer,
      accent: AppColors.darkInfoAccent,
    ),
  );

  // ---------------------------------------------------------------------------
  // Light Theme
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.emeraldPrimary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.emeraldContainerLight,
      onPrimaryContainer: AppColors.emeraldDark,
      secondary: AppColors.slatePrimary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.slateContainerLight,
      onSecondaryContainer: AppColors.slateDark,
      tertiary: AppColors.amberPrimary,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.amberContainerLight,
      onTertiaryContainer: AppColors.amberDark,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      onSurfaceVariant: AppColors.lightTextSecondary,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      outline: Color(0xFFBDC9C3),
      outlineVariant: Color(0xFFDEE5E1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: AppTextStyles.textTheme(
        AppColors.lightTextPrimary,
        AppColors.lightTextSecondary,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: Color(0xFFE2EBE6)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightCard,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.emeraldPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.emeraldPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.emeraldPrimary;
          }
          return const Color(0xFF88968F);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.emeraldLight.withValues(alpha: 0.38);
          }
          return const Color(0xFFE0E6E3);
        }),
      ),
      extensions: const [
        _lightStatusColors,
        FocusThemeExtension(
          calmContainer: Color(0xFFE0F2F1),
          alertContainer: Color(0xFFFFEBEE),
          streakColor: AppColors.amberPrimary,
          timeSavedGlow: Color(0xFF26A69A),
          breathingRingColor: AppColors.emeraldPrimary,
          frictionTrackColor: Color(0xFFCFD8DC),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dark Theme
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.emeraldLight,
      onPrimary: Color(0xFF00382E),
      primaryContainer: AppColors.emeraldContainerDark,
      onPrimaryContainer: Color(0xFF80CBC4),
      secondary: AppColors.slateLight,
      onSecondary: Color(0xFF1E282D),
      secondaryContainer: AppColors.slateContainerDark,
      onSecondaryContainer: Color(0xFFB0BEC5),
      tertiary: AppColors.amberLight,
      onTertiary: Color(0xFF332000),
      tertiaryContainer: AppColors.amberContainerDark,
      onTertiaryContainer: Color(0xFFFFD54F),
      error: AppColors.errorLight,
      onError: Color(0xFF5C0000),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      outline: Color(0xFF3B4842),
      outlineVariant: Color(0xFF242E29),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: AppTextStyles.textTheme(
        AppColors.darkTextPrimary,
        AppColors.darkTextSecondary,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: Color(0xFF242E29)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkCard,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.emeraldLight,
          foregroundColor: const Color(0xFF00382E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.emeraldLight,
          foregroundColor: const Color(0xFF00382E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.emeraldLight;
          }
          return const Color(0xFF6E7E77);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.emeraldDark;
          }
          return const Color(0xFF1E2824);
        }),
      ),
      extensions: const [
        _darkStatusColors,
        FocusThemeExtension(
          calmContainer: Color(0xFF00382E),
          alertContainer: Color(0xFF3E1418),
          streakColor: AppColors.amberLight,
          timeSavedGlow: Color(0xFF80CBC4),
          breathingRingColor: AppColors.emeraldLight,
          frictionTrackColor: Color(0xFF37474F),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // AMOLED Pure Black Theme
  // ---------------------------------------------------------------------------
  static ThemeData get amoledTheme {
    final baseDark = darkTheme;
    final colorScheme = baseDark.colorScheme.copyWith(
      surface: AppColors.amoledSurface,
      onSurface: AppColors.amoledTextPrimary,
      surfaceContainerHighest: AppColors.amoledSurfaceVariant,
      onSurfaceVariant: AppColors.amoledTextSecondary,
    );

    return baseDark.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.amoledBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.amoledBackground,
        foregroundColor: AppColors.amoledTextPrimary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.amoledCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: Color(0xFF1F242C)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.amoledCard,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      extensions: const [
        _amoledStatusColors,
        FocusThemeExtension(
          calmContainer: Color(0xFF00241E),
          alertContainer: Color(0xFF280B0F),
          streakColor: AppColors.amberLight,
          timeSavedGlow: Color(0xFF4DB6AC),
          breathingRingColor: AppColors.emeraldLight,
          frictionTrackColor: Color(0xFF1E282D),
        ),
      ],
    );
  }

  /// Selects the proper [ThemeData] given the active [themeMode] string and host [systemBrightness].
  static ThemeData themeDataForMode(
      String themeMode, Brightness systemBrightness) {
    switch (themeMode.toLowerCase()) {
      case 'light':
        return lightTheme;
      case 'dark':
        return darkTheme;
      case 'amoled':
        return amoledTheme;
      case 'system':
      default:
        return systemBrightness == Brightness.dark ? darkTheme : lightTheme;
    }
  }
}
