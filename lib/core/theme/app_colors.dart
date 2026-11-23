import 'package:flutter/material.dart';

/// Semantic palette and brand color definitions for BlockReels.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Primary Palette: Emerald Sage (Calming, Mindful Focus)
  // ---------------------------------------------------------------------------
  static const Color emeraldPrimary = Color(0xFF00796B);
  static const Color emeraldLight = Color(0xFF26A69A);
  static const Color emeraldDark = Color(0xFF004D40);
  static const Color emeraldContainerLight = Color(0xFFE0F2F1);
  static const Color emeraldContainerDark = Color(0xFF00382E);

  // ---------------------------------------------------------------------------
  // Secondary Palette: Slate Blue (Clarity, Structure)
  // ---------------------------------------------------------------------------
  static const Color slatePrimary = Color(0xFF455A64);
  static const Color slateLight = Color(0xFF78909C);
  static const Color slateDark = Color(0xFF263238);
  static const Color slateContainerLight = Color(0xFFECEFF1);
  static const Color slateContainerDark = Color(0xFF1E282D);

  // ---------------------------------------------------------------------------
  // Tertiary Palette: Warm Amber (Milestones, Streaks, Attention)
  // ---------------------------------------------------------------------------
  static const Color amberPrimary = Color(0xFFFF8F00);
  static const Color amberLight = Color(0xFFFFB74D);
  static const Color amberDark = Color(0xFFE65100);
  static const Color amberContainerLight = Color(0xFFFFF8E1);
  static const Color amberContainerDark = Color(0xFF332000);

  // ---------------------------------------------------------------------------
  // Semantic Colors
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFED6C02);
  static const Color warningLight = Color(0xFFFFA726);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color info = Color(0xFF0288D1);
  static const Color infoLight = Color(0xFF29B6F6);

  // Complete semantic state sets. Containers are intentionally quiet while
  // their foreground and accent colors maintain readable contrast.
  static const Color lightSuccessContainer = Color(0xFFE7F5EC);
  static const Color lightOnSuccessContainer = Color(0xFF165B32);
  static const Color lightSuccessAccent = Color(0xFF247B4B);
  static const Color lightWarningContainer = Color(0xFFFFF4DB);
  static const Color lightOnWarningContainer = Color(0xFF5B3A00);
  static const Color lightWarningAccent = Color(0xFF9A5B00);
  static const Color lightErrorContainer = Color(0xFFFDEBEC);
  static const Color lightOnErrorContainer = Color(0xFF7D1F26);
  static const Color lightErrorAccent = Color(0xFFB3261E);
  static const Color lightInfoContainer = Color(0xFFE3F3F0);
  static const Color lightOnInfoContainer = Color(0xFF17453F);
  static const Color lightInfoAccent = Color(0xFF00695C);

  static const Color darkSuccessContainer = Color(0xFF102A1B);
  static const Color darkOnSuccessContainer = Color(0xFFB8F2C8);
  static const Color darkSuccessAccent = Color(0xFF65C787);
  static const Color darkWarningContainer = Color(0xFF30230B);
  static const Color darkOnWarningContainer = Color(0xFFFFDEA0);
  static const Color darkWarningAccent = Color(0xFFF3B84B);
  static const Color darkErrorContainer = Color(0xFF351417);
  static const Color darkOnErrorContainer = Color(0xFFFFC7CA);
  static const Color darkErrorAccent = Color(0xFFFF8A8A);
  static const Color darkInfoContainer = Color(0xFF0B2925);
  static const Color darkOnInfoContainer = Color(0xFFB7E5DE);
  static const Color darkInfoAccent = Color(0xFF63C7B9);

  static const Color amoledSuccessContainer = Color(0xFF07140C);
  static const Color amoledWarningContainer = Color(0xFF171005);
  static const Color amoledErrorContainer = Color(0xFF1B090B);
  static const Color amoledInfoContainer = Color(0xFF061512);

  // ---------------------------------------------------------------------------
  // Surfaces & Backgrounds - Light Mode
  // ---------------------------------------------------------------------------
  static const Color lightBackground = Color(0xFFF0F5F2);
  static const Color lightSurface = Color(0xFFF8FBF9);
  static const Color lightSurfaceVariant = Color(0xFFE2EBE6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF131F1A);
  static const Color lightTextSecondary = Color(0xFF53635B);

  // ---------------------------------------------------------------------------
  // Surfaces & Backgrounds - Dark Mode
  // ---------------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF0A0F0D);
  static const Color darkSurface = Color(0xFF121816);
  static const Color darkSurfaceVariant = Color(0xFF1B2421);
  static const Color darkCard = Color(0xFF1E2824);
  static const Color darkTextPrimary = Color(0xFFE5EDE8);
  static const Color darkTextSecondary = Color(0xFF9BAFA6);

  // ---------------------------------------------------------------------------
  // Surfaces & Backgrounds - AMOLED Pure Black Mode
  // ---------------------------------------------------------------------------
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF000000);
  static const Color amoledSurfaceVariant = Color(0xFF0D1117);
  static const Color amoledCard = Color(0xFF12151B);
  static const Color amoledTextPrimary = Color(0xFFF0F6FC);
  static const Color amoledTextSecondary = Color(0xFF8B949E);

  // ---------------------------------------------------------------------------
  // Target App Brand Signatures (for Surgical App Cards)
  // ---------------------------------------------------------------------------
  static const Color instagramGradientStart = Color(0xFF833AB4);
  static const Color instagramGradientEnd = Color(0xFFFD1D1D);
  static const Color youtubeRed = Color(0xFFFF0000);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color tiktokCyan = Color(0xFF00F2FE);
  static const Color tiktokPink = Color(0xFFFE2C55);
}
