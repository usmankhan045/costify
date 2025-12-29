import 'package:flutter/material.dart';

/// Application color palette
/// Using a warm construction-themed palette with deep teal and amber accents
class AppColors {
  AppColors._();

  // Primary Colors - Deep Teal
  static const Color primary = Color(0xFF0D6E6E);
  static const Color primaryLight = Color(0xFF4A9D9D);
  static const Color primaryDark = Color(0xFF084545);
  static const Color primaryContainer = Color(0xFFB8E5E5);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF042020);

  // Secondary Colors - Warm Amber
  static const Color secondary = Color(0xFFE88D2C);
  static const Color secondaryLight = Color(0xFFFFB95D);
  static const Color secondaryDark = Color(0xFFAF6000);
  static const Color secondaryContainer = Color(0xFFFFDDB8);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF2D1600);

  // Tertiary Colors - Slate Blue
  static const Color tertiary = Color(0xFF5B6A8A);
  static const Color tertiaryContainer = Color(0xFFD8E2FF);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF141C2E);

  // Surface Colors - Light Theme
  static const Color surface = Color(0xFFF8FAF8);
  static const Color surfaceVariant = Color(0xFFE7EBE7);
  static const Color surfaceContainer = Color(0xFFEEF2EE);
  static const Color surfaceContainerHigh = Color(0xFFE3E7E3);
  static const Color surfaceContainerLow = Color(0xFFF5F9F5);
  static const Color onSurface = Color(0xFF1A1C1A);
  static const Color onSurfaceVariant = Color(0xFF424442);
  static const Color outline = Color(0xFF727472);
  static const Color outlineVariant = Color(0xFFC2C4C2);

  // Surface Colors - Dark Theme
  static const Color surfaceDark = Color(0xFF121412);
  static const Color surfaceVariantDark = Color(0xFF2A2C2A);
  static const Color surfaceContainerDark = Color(0xFF1E201E);
  static const Color surfaceContainerHighDark = Color(0xFF282A28);
  static const Color surfaceContainerLowDark = Color(0xFF181A18);
  static const Color onSurfaceDark = Color(0xFFE2E4E2);
  static const Color onSurfaceVariantDark = Color(0xFFC2C4C2);
  static const Color outlineDark = Color(0xFF8C8E8C);
  static const Color outlineVariantDark = Color(0xFF424442);

  // Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFF81C784);
  static const Color successContainer = Color(0xFFD4EDDA);
  static const Color onSuccess = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFE57373);
  static const Color errorContainer = Color(0xFFF8D7DA);
  static const Color onError = Color(0xFFFFFFFF);

  static const Color warning = Color(0xFFF9A825);
  static const Color warningLight = Color(0xFFFFE082);
  static const Color warningContainer = Color(0xFFFFF3CD);
  static const Color onWarning = Color(0xFF000000);

  static const Color info = Color(0xFF1976D2);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoContainer = Color(0xFFD1ECF1);
  static const Color onInfo = Color(0xFFFFFFFF);

  // Expense Category Colors
  static const Color materials = Color(0xFF8B4513);
  static const Color labor = Color(0xFF4169E1);
  static const Color equipment = Color(0xFF708090);
  static const Color transport = Color(0xFF228B22);
  static const Color utilities = Color(0xFFDAA520);
  static const Color permits = Color(0xFF800080);
  static const Color contractors = Color(0xFFDC143C);
  static const Color food = Color(0xFFFF6347); // Tomato red for food
  static const Color miscellaneous = Color(0xFF20B2AA);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryLight],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D6E6E), Color(0xFF1A8F8F)],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E201E), Color(0xFF2A2C2A)],
  );

  // Shadows
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get strongShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  // Helper to get category color
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'materials':
        return materials;
      case 'labor':
        return labor;
      case 'equipment':
        return equipment;
      case 'transport':
        return transport;
      case 'utilities':
        return utilities;
      case 'permits':
      case 'permits & fees':
        return permits;
      case 'contractors':
        return contractors;
      case 'food':
        return food;
      default:
        return miscellaneous;
    }
  }
}

