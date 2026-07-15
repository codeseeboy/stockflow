import 'package:flutter/material.dart';

/// Central palette for StockFlow.
///
/// Plain and neutral: charcoal for primary actions, white/gray surfaces, and
/// colour only where it carries meaning (green = open/ok, amber = attention,
/// red = problem). No gradients, no glows, nothing decorative — the content
/// does the talking.
class AppColors {
  AppColors._();

  // Primary — neutral charcoal (buttons, links, progress)
  static const brand = Color(0xFF24292F);
  static const brandDark = Color(0xFF16191D);
  static const brandLight = Color(0xFF57606A);
  static const brandWash = Color(0xFFF0F2F4);

  // Accent — subdued gold (used sparingly: in-lieu labels, carry-over tags)
  static const accent = Color(0xFF9C7018);
  static const accentWash = Color(0xFFF5EEDC);

  // Status — muted, readable
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFA36A00);
  static const danger = Color(0xFFC03B3F);
  static const successWash = Color(0xFFE9F3EA);
  static const warningWash = Color(0xFFF7EFDE);
  static const dangerWash = Color(0xFFF9E9E9);

  // Light neutrals — plain grays, no colour tint
  static const bg = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF0F3);
  static const ink = Color(0xFF20262E);
  static const inkSoft = Color(0xFF5B6570);
  static const inkFaint = Color(0xFF97A0A9);
  static const line = Color(0xFFE0E4E9);

  // Dark neutrals
  static const dBg = Color(0xFF11151A);
  static const dSurface = Color(0xFF181E25);
  static const dSurfaceMuted = Color(0xFF20272F);
  static const dInk = Color(0xFFE8ECF0);
  static const dInkSoft = Color(0xFF9AA5B0);
  static const dLine = Color(0xFF2A323C);

  // Dark status washes (muted tints that read on dark surfaces)
  static const dSuccessWash = Color(0xFF1D3020);
  static const dWarningWash = Color(0xFF352B16);
  static const dDangerWash = Color(0xFF381F20);
  static const dBrandWash = Color(0xFF272E36);

  // Category accents — muted so they read as labels, not decoration
  static const cGrains = Color(0xFFB08514);
  static const cPulses = Color(0xFF8A5FAB);
  static const cVeg = Color(0xFF3B8558);
  static const cFruits = Color(0xFFB65546);
  static const cDairy = Color(0xFF3D6FA8);
  static const cBakery = Color(0xFFAF6F34);
  static const cEssentials = Color(0xFF2E8783);

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

/// Small, consistent corner radii — squarer = more formal.
class AppRadius {
  AppRadius._();
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 10.0;
  static const xl = 12.0;
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
      primary: const Color(0xFFCFD6DD),
      onPrimary: const Color(0xFF16191D),
      primaryContainer: AppColors.dBrandWash,
      onPrimaryContainer: AppColors.dInk,
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
