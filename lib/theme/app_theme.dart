import 'package:flutter/material.dart';

/// Central palette for StockFlow.
///
/// Brand is a fresh emerald (food / freshness) with a warm amber accent.
/// Deliberately NOT blue-dominant. A spread of category colours keeps the
/// catalogue lively and easy to scan.
class AppColors {
  AppColors._();

  // Brand
  static const brand = Color(0xFF12936A);
  static const brandDark = Color(0xFF0B6E4F);
  static const brandLight = Color(0xFF3FBE91);
  static const brandWash = Color(0xFFE7F6EF);

  // Accent
  static const accent = Color(0xFFF2A23C);
  static const accentWash = Color(0xFFFCEBD0);

  // Status
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFEAA60B);
  static const danger = Color(0xFFE5484D);
  static const successWash = Color(0xFFE4F6EA);
  static const warningWash = Color(0xFFFBF0D4);
  static const dangerWash = Color(0xFFFBE6E7);

  // Light neutrals
  static const bg = Color(0xFFF4F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEFF3F1);
  static const ink = Color(0xFF12201C);
  static const inkSoft = Color(0xFF5E6F69);
  static const inkFaint = Color(0xFF93A29C);
  static const line = Color(0xFFE5ECE8);

  // Dark neutrals
  static const dBg = Color(0xFF0D1714);
  static const dSurface = Color(0xFF161F1C);
  static const dSurfaceMuted = Color(0xFF1E2826);
  static const dInk = Color(0xFFEDF2EF);
  static const dInkSoft = Color(0xFFA0B0AA);
  static const dLine = Color(0xFF273230);

  // Dark status washes (muted tints that read on dark surfaces)
  static const dSuccessWash = Color(0xFF1A3328);
  static const dWarningWash = Color(0xFF3A2E14);
  static const dDangerWash = Color(0xFF3A1E20);
  static const dBrandWash = Color(0xFF1A3D2E);

  // Category accents (variety = easy scanning; blue is just one of many)
  static const cGrains = Color(0xFFD9A21B);
  static const cPulses = Color(0xFFB06AD6);
  static const cVeg = Color(0xFF36A85A);
  static const cFruits = Color(0xFFE5604D);
  static const cDairy = Color(0xFF3E86E0);
  static const cBakery = Color(0xFFE08A3C);
  static const cEssentials = Color(0xFF14A8A0);

  static const chartPalette = [
    cGrains,
    cVeg,
    cFruits,
    cDairy,
    cPulses,
    cBakery,
    cEssentials,
  ];
}

class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandWash,
      onPrimaryContainer: AppColors.brandDark,
      secondary: AppColors.accent,
      onSecondary: const Color(0xFF3A2606),
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.line,
      outlineVariant: AppColors.line,
      error: AppColors.danger,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.bg,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.brandLight,
      onPrimary: const Color(0xFF03251A),
      primaryContainer: AppColors.dBrandWash,
      onPrimaryContainer: AppColors.brandWash,
      secondary: AppColors.accent,
      onSecondary: const Color(0xFF2A1A06),
      secondaryContainer: const Color(0xFF3A2A12),
      onSecondaryContainer: AppColors.accentWash,
      surface: AppColors.dSurface,
      onSurface: AppColors.dInk,
      onSurfaceVariant: AppColors.dInkSoft,
      surfaceContainerHighest: AppColors.dSurfaceMuted,
      surfaceContainer: AppColors.dSurfaceMuted,
      outline: AppColors.dLine,
      outlineVariant: AppColors.dLine,
      error: const Color(0xFFFF6B6F),
      onError: const Color(0xFF3A0A0C),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.dBg,
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Jakarta',
      splashFactory: InkSparkle.splashFactory,
    );

    final ink = scheme.onSurface;
    final soft = isLight ? AppColors.inkSoft : AppColors.dInkSoft;

    final textTheme = base.textTheme.copyWith(
      displaySmall: TextStyle(fontWeight: FontWeight.w800, fontSize: 30, color: ink, letterSpacing: -0.5),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: ink, letterSpacing: -0.4),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, color: ink, letterSpacing: -0.3),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: ink, letterSpacing: -0.2),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: ink),
      titleSmall: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: ink),
      bodyLarge: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: ink),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5, color: soft),
      bodySmall: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: soft),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: ink),
      labelMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: soft),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: soft),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.surfaceMuted : AppColors.dSurfaceMuted,
        hintStyle: TextStyle(color: isLight ? AppColors.inkFaint : AppColors.dInkSoft, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppColors.surfaceMuted : AppColors.dSurfaceMuted,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: ink),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: isLight ? AppColors.brandWash : AppColors.dBrandWash,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? scheme.primary : soft, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Jakarta',
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: selected ? scheme.primary : soft,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: isLight ? AppColors.brandWash : AppColors.dBrandWash,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: soft),
        selectedLabelTextStyle: TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w700, fontSize: 12.5, color: scheme.primary),
        unselectedLabelTextStyle: TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w600, fontSize: 12.5, color: soft),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? AppColors.ink : AppColors.dSurfaceMuted,
        contentTextStyle: TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w600, color: isLight ? Colors.white : AppColors.dInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}
