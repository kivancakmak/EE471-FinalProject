import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Vitality Core" tasarım sisteminin renkleri (Material 3 token'ları).
class AppColors {
  AppColors._();

  // Marka yeşilleri
  static const primaryDeep = Color(0xFF006C49); // koyu yeşil (açık tema primary)
  static const emerald = Color(0xFF10B981); // canlı zümrüt (vurgu)
  static const mint = Color(0xFF4EDEA3); // parlak nane (koyu tema primary)

  // Açık tema
  static const lightBg = Color(0xFFF4FBF4);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightOnSurface = Color(0xFF161D19);
  static const lightOnSurfaceVariant = Color(0xFF3C4A42);
  static const lightOutlineVariant = Color(0xFFBBCABF);
  static const lightError = Color(0xFFBA1A1A);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const onLightErrorContainer = Color(0xFF93000A);

  // Koyu tema
  static const darkBg = Color(0xFF0B1326);
  static const darkCard = Color(0xFF171F33);
  static const darkInput = Color(0xFF222A3D);
  static const darkOnSurface = Color(0xFFDAE2FD);
  static const darkOnSurfaceVariant = Color(0xFFBBCABF);
  static const darkOutlineVariant = Color(0xFF3C4A42);
  static const darkError = Color(0xFFFFB4AB);
  static const darkErrorContainer = Color(0xFF93000A);
  static const onDarkErrorContainer = Color(0xFFFFDAD6);

  /// Kalori halkası / parlak vurgu rengi (tema bazlı).
  static const accentLight = emerald;
  static const accentDark = mint;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryDeep,
      onPrimary: Colors.white,
      primaryContainer: AppColors.emerald,
      onPrimaryContainer: Color(0xFF00422B),
      // İkincil rengi vurgu yeşili yapıyoruz: tüm widget'lar yeşil kalsın.
      secondary: AppColors.emerald,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD6F5E7),
      onSecondaryContainer: Color(0xFF00422B),
      error: AppColors.lightError,
      onError: Colors.white,
      errorContainer: AppColors.lightErrorContainer,
      onErrorContainer: AppColors.onLightErrorContainer,
      surface: AppColors.lightCard,
      onSurface: AppColors.lightOnSurface,
      onSurfaceVariant: AppColors.lightOnSurfaceVariant,
      outline: Color(0xFF6C7A71),
      outlineVariant: AppColors.lightOutlineVariant,
      inverseSurface: Color(0xFF2B322D),
      onInverseSurface: Color(0xFFEBF3EB),
      inversePrimary: AppColors.mint,
    );
    return _build(
      scheme: scheme,
      bg: AppColors.lightBg,
      card: AppColors.lightCard,
      inputFill: AppColors.lightCard,
      buttonBg: AppColors.primaryDeep,
      buttonFg: Colors.white,
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.mint,
      onPrimary: Color(0xFF003824),
      primaryContainer: AppColors.emerald,
      onPrimaryContainer: Color(0xFF00422B),
      secondary: AppColors.mint,
      onSecondary: Color(0xFF003824),
      secondaryContainer: Color(0xFF005236),
      onSecondaryContainer: Color(0xFF6FFBBE),
      error: AppColors.darkError,
      onError: Color(0xFF690005),
      errorContainer: AppColors.darkErrorContainer,
      onErrorContainer: AppColors.onDarkErrorContainer,
      surface: AppColors.darkCard,
      onSurface: AppColors.darkOnSurface,
      onSurfaceVariant: AppColors.darkOnSurfaceVariant,
      outline: Color(0xFF86948A),
      outlineVariant: AppColors.darkOutlineVariant,
      inverseSurface: Color(0xFFDAE2FD),
      onInverseSurface: Color(0xFF283044),
      inversePrimary: AppColors.primaryDeep,
    );
    return _build(
      scheme: scheme,
      bg: AppColors.darkBg,
      card: AppColors.darkCard,
      inputFill: AppColors.darkInput,
      buttonBg: AppColors.emerald,
      buttonFg: const Color(0xFF003824),
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color bg,
    required Color card,
    required Color inputFill,
    required Color buttonBg,
    required Color buttonFg,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        shadowColor: Colors.black.withValues(alpha: 0.04),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBg,
          foregroundColor: buttonFg,
          minimumSize: const Size.fromHeight(54),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: scheme.secondary,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? scheme.secondary : null),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
