import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

enum AppThemePreset { modern, classic, emerald }

extension AppThemePresetLabel on AppThemePreset {
  String get label => switch (this) {
        AppThemePreset.modern => 'Modern Blue',
        AppThemePreset.classic => 'Classic Navy',
        AppThemePreset.emerald => 'Emerald',
      };

  String get description => switch (this) {
        AppThemePreset.modern => 'Clean and contemporary',
        AppThemePreset.classic => 'Traditional school identity',
        AppThemePreset.emerald => 'Calm and academic',
      };
}

class AppThemePalette extends ThemeExtension<AppThemePalette> {
  final Color brand;
  final Color brandDark;
  final Color accent;
  final Color canvas;
  final Color surface;
  final Color border;
  final LinearGradient heroGradient;

  const AppThemePalette({
    required this.brand,
    required this.brandDark,
    required this.accent,
    required this.canvas,
    required this.surface,
    required this.border,
    required this.heroGradient,
  });

  @override
  AppThemePalette copyWith({
    Color? brand,
    Color? brandDark,
    Color? accent,
    Color? canvas,
    Color? surface,
    Color? border,
    LinearGradient? heroGradient,
  }) {
    return AppThemePalette(
      brand: brand ?? this.brand,
      brandDark: brandDark ?? this.brandDark,
      accent: accent ?? this.accent,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  AppThemePalette lerp(covariant AppThemePalette? other, double t) {
    if (other == null) return this;
    return AppThemePalette(
      brand: Color.lerp(brand, other.brand, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemePalette get palette => Theme.of(this).extension<AppThemePalette>()!;
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => forPreset(AppThemePreset.modern);

  static ThemeData forPreset(AppThemePreset preset) {
    final palette = _paletteFor(preset);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: palette.brand,
        onPrimary: AppColors.white,
        secondary: palette.accent,
        onSecondary: AppColors.white,
        tertiary: palette.accent,
        error: AppColors.error,
        onError: AppColors.white,
        surface: palette.surface,
        onSurface: AppColors.textPrimary,
        outline: palette.border,
      ),
      scaffoldBackgroundColor: palette.canvas,
      visualDensity: VisualDensity.compact,
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.nunitoSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme:
            const IconThemeData(color: AppColors.textSecondary, size: 21),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: palette.border, width: 1),
        ),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: palette.border),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: AppColors.white,
          elevation: 0,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.brand,
          side: BorderSide(color: palette.border, width: 1),
          elevation: 0,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brand,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.brand, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(
          color: AppColors.textLight,
          fontSize: 13,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(palette.canvas),
        headingRowHeight: 38,
        dataRowMinHeight: 38,
        dataRowMaxHeight: 44,
        dividerThickness: 1.0,
        headingTextStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppColors.textSecondary,
        ),
        dataTextStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),

      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navyDark,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.canvas,
        selectedColor: palette.brand,
        labelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: palette.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      extensions: [palette],
    );
  }

  static AppThemePalette _paletteFor(AppThemePreset preset) {
    return switch (preset) {
      AppThemePreset.modern => const AppThemePalette(
          brand: Color(0xFF0F8576),      // Katasticho Teal-600
          brandDark: Color(0xFF0A5C52),  // Katasticho Deep Teal
          accent: Color(0xFF14A08C),     // Katasticho Teal-500
          canvas: Color(0xFFF7F7F5),     // Katasticho Warm Neutral (--bg-app)
          surface: Colors.white,
          border: Color(0xFFE5E5E1),     // Katasticho Warm Border (--border)
          heroGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A5C52), Color(0xFF0F8576), Color(0xFF14A08C)],
          ),
        ),
      AppThemePreset.classic => const AppThemePalette(
          brand: Color(0xFF1B3A5C),
          brandDark: Color(0xFF122840),
          accent: Color(0xFFC8922A),
          canvas: Color(0xFFF9F7F2),
          surface: Colors.white,
          border: Color(0xFFE7E0D4),
          heroGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF122840), Color(0xFF1B3A5C), Color(0xFF31597D)],
          ),
        ),
      AppThemePreset.emerald => const AppThemePalette(
          brand: Color(0xFF115E59),
          brandDark: Color(0xFF083F3C),
          accent: Color(0xFF0D9488),
          canvas: Color(0xFFF4F8F7),
          surface: Colors.white,
          border: Color(0xFFD9E7E4),
          heroGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF083F3C), Color(0xFF115E59), Color(0xFF0F766E)],
          ),
        ),
    };
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // Display
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),

      // Headline
      headlineLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),

      // Title
      titleLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),

      // Body — Inter (finance-SaaS standard)
      bodyLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.35,
      ),

      // Label
      labelLarge: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      ),
    );
  }
}
