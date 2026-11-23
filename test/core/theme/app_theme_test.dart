import 'package:block_reels/core/theme/app_colors.dart';
import 'package:block_reels/core/theme/app_text_styles.dart';
import 'package:block_reels/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    final lighter =
        firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
    final darker =
        firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }

  group('AppTheme & Design System Tests', () {
    test('Light theme configures Material 3 with Emerald/Slate palette', () {
      final light = AppTheme.lightTheme;

      expect(light.useMaterial3, isTrue);
      expect(light.brightness, Brightness.light);
      expect(light.colorScheme.primary, AppColors.emeraldPrimary);
      expect(light.colorScheme.secondary, AppColors.slatePrimary);
      expect(light.scaffoldBackgroundColor, AppColors.lightBackground);

      final extension = light.extension<FocusThemeExtension>();
      expect(extension, isNotNull);
      expect(extension!.streakColor, AppColors.amberPrimary);
      expect(extension.breathingRingColor, AppColors.emeraldPrimary);
      expect(light.cardTheme.margin, EdgeInsets.zero);
    });

    test('Dark theme configures Material 3 with dark Emerald/Slate palette',
        () {
      final dark = AppTheme.darkTheme;

      expect(dark.useMaterial3, isTrue);
      expect(dark.brightness, Brightness.dark);
      expect(dark.colorScheme.primary, AppColors.emeraldLight);
      expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);

      final extension = dark.extension<FocusThemeExtension>();
      expect(extension, isNotNull);
      expect(extension!.streakColor, AppColors.amberLight);
      expect(dark.cardTheme.margin, EdgeInsets.zero);
    });

    test('AMOLED theme configures pure black surface and background', () {
      final amoled = AppTheme.amoledTheme;

      expect(amoled.useMaterial3, isTrue);
      expect(amoled.brightness, Brightness.dark);
      expect(amoled.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(amoled.colorScheme.surface, const Color(0xFF000000));

      final extension = amoled.extension<FocusThemeExtension>();
      expect(extension, isNotNull);
      expect(amoled.colorScheme.onSurface, AppColors.amoledTextPrimary);
      expect(amoled.cardTheme.margin, EdgeInsets.zero);
    });

    test('semantic status sets meet text and non-text contrast in every mode',
        () {
      final themes = {
        'light': AppTheme.lightTheme,
        'dark': AppTheme.darkTheme,
        'amoled': AppTheme.amoledTheme,
      };

      for (final themeEntry in themes.entries) {
        final extension = themeEntry.value.extension<StatusThemeExtension>();
        expect(extension, isNotNull, reason: themeEntry.key);
        final states = {
          'success': extension!.success,
          'warning': extension.warning,
          'error': extension.error,
          'info': extension.info,
        };

        for (final stateEntry in states.entries) {
          final reason = '${themeEntry.key} ${stateEntry.key}';
          expect(
            contrastRatio(
              stateEntry.value.foreground,
              stateEntry.value.container,
            ),
            greaterThanOrEqualTo(4.5),
            reason: '$reason text',
          );
          expect(
            contrastRatio(
              stateEntry.value.accent,
              stateEntry.value.container,
            ),
            greaterThanOrEqualTo(3),
            reason: '$reason icon',
          );
        }
      }
    });

    test('semantic accents remain readable on KPI card surfaces', () {
      for (final theme in [
        AppTheme.lightTheme,
        AppTheme.darkTheme,
        AppTheme.amoledTheme,
      ]) {
        final extension = theme.extension<StatusThemeExtension>()!;
        final cardColor = theme.cardTheme.color!;
        expect(
          contrastRatio(extension.success.accent, cardColor),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(extension.info.accent, cardColor),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('FocusThemeExtension copyWith and lerp interpolate colors cleanly',
        () {
      const ext1 = FocusThemeExtension(
        calmContainer: Color(0xFF000000),
        alertContainer: Color(0xFF111111),
        streakColor: Color(0xFF222222),
        timeSavedGlow: Color(0xFF333333),
        breathingRingColor: Color(0xFF444444),
        frictionTrackColor: Color(0xFF555555),
      );

      const ext2 = FocusThemeExtension(
        calmContainer: Color(0xFFFFFFFF),
        alertContainer: Color(0xFFEEEEEE),
        streakColor: Color(0xFFDDDDDD),
        timeSavedGlow: Color(0xFFCCCCCC),
        breathingRingColor: Color(0xFFBBBBBB),
        frictionTrackColor: Color(0xFFAAAAAA),
      );

      final lerped = ext1.lerp(ext2, 0.5);
      expect(lerped.calmContainer, isNotNull);
      expect(lerped.streakColor, isNotNull);

      final copied = ext1.copyWith(calmContainer: const Color(0xFF123456));
      expect(copied.calmContainer, const Color(0xFF123456));
      expect(copied.alertContainer, ext1.alertContainer);
    });

    test('themeDataForMode dynamically returns correct theme for mode string',
        () {
      final lightMode = AppTheme.themeDataForMode('light', Brightness.dark);
      expect(lightMode.brightness, Brightness.light);

      final darkMode = AppTheme.themeDataForMode('dark', Brightness.light);
      expect(darkMode.brightness, Brightness.dark);

      final amoledMode = AppTheme.themeDataForMode('amoled', Brightness.light);
      expect(amoledMode.scaffoldBackgroundColor, const Color(0xFF000000));

      final systemDark = AppTheme.themeDataForMode('system', Brightness.dark);
      expect(systemDark.brightness, Brightness.dark);

      final systemLight = AppTheme.themeDataForMode('system', Brightness.light);
      expect(systemLight.brightness, Brightness.light);
    });

    test('AppTextStyles generates full Material 3 textTheme scale', () {
      final textTheme = AppTextStyles.textTheme(
        AppColors.lightTextPrimary,
        AppColors.lightTextSecondary,
      );

      expect(textTheme.displayLarge?.fontSize, 57);
      expect(textTheme.headlineLarge?.fontSize, 32);
      expect(textTheme.titleMedium?.fontSize, 16);
      expect(textTheme.bodyMedium?.fontSize, 14);
      expect(textTheme.labelSmall?.fontSize, 11);
    });
  });
}
