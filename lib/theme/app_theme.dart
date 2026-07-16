import 'package:flutter/material.dart';

/// Central palette for StockFlow.
///
/// The brand green (matches the logo) on clean white/gray surfaces. Flat by
/// rule — no gradients, no glows. Colour carries meaning: green = brand/open,
/// amber = attention, red = problem; category colours make the catalogue easy
/// to scan.
class AppColors {
  AppColors._();

  // Brand — the StockFlow green
  static const brand = Color(0xFF12936A);
  static const brandDark = Color(0xFF0B6E4F);
  static const brandLight = Color(0xFF3FBE91);
  static const brandWash = Color(0xFFE7F6EF);

  // Accent — warm amber (in-lieu labels, carry-over tags)
  static const accent = Color(0xFFB97D14);
  static const accentWash = Color(0xFFF9EFD9);

  // Status
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFB97D14);
  static const danger = Color(0xFFD64545);
  static const successWash = Color(0xFFE4F6EA);
  static const warningWash = Color(0xFFF9EFD9);
  static const dangerWash = Color(0xFFFBE8E8);

  // Light neutrals
  static const bg = Color(0xFFF5F7F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEFF2F0);
  static const ink = Color(0xFF17231E);
  static const inkSoft = Color(0xFF5D6C66);
  static const inkFaint = Color(0xFF95A29C);
  static const line = Color(0xFFE2E8E5);

  // Dark neutrals — a real dark navy, not inverted gray
  static const dBg = Color(0xFF0A1220);
  static const dSurface = Color(0xFF111B2E);
  static const dSurfaceMuted = Color(0xFF1A2740);
  static const dInk = Color(0xFFE7EDF6);
  static const dInkSoft = Color(0xFF9BAAC2);
  static const dLine = Color(0xFF25344E);

  // Dark status washes (muted tints that read on navy surfaces)
  static const dSuccessWash = Color(0xFF163526);
  static const dWarningWash = Color(0xFF33290F);
  static const dDangerWash = Color(0xFF391D22);
  static const dBrandWash = Color(0xFF143B2C);

  // Category accents
  static const cGrains = Color(0xFFCB9A1C);
  static const cPulses = Color(0xFF9B62BF);
  static const cVeg = Color(0xFF36A85A);
  static const cFruits = Color(0xFFDB5B49);
  static const cDairy = Color(0xFF3E86E0);
  static const cBakery = Color(0xFFD08238);
  static const cEssentials = Color(0xFF16A09A);

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

/// Consistent corner radii — soft enough to feel like an app, not a document.
class AppRadius {
  AppRadius._();
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 18.0;
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
    );

    final ink = scheme.onSurface;
    final soft = isLight ? AppColors.inkSoft : AppColors.dInkSoft;

    // Calm weights, slightly larger body text — easy reading for every user.
    final textTheme = base.textTheme.copyWith(
      displaySmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 28, color: ink),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 24, color: ink),
      headlineSmall: TextStyle(fontWeight: FontWeight.w700, fontSize: 21, color: ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: ink),
      titleSmall: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: ink),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400, fontSize: 15, color: ink),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, fontSize: 14, color: soft),
      bodySmall: TextStyle(fontWeight: FontWeight.w400, fontSize: 12.5, color: soft),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: ink),
      labelMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: soft),
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
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: scheme.outline),
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w600, fontSize: 14.5),
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
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ink),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
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
