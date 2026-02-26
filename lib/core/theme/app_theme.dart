import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.navy,
        onPrimary: AppColors.white,
        secondary: AppColors.gold,
        onSecondary: AppColors.white,
        tertiary: AppColors.goldLight,
        error: AppColors.error,
        onError: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.textPrimary,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLG),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSM),
          ),
          textStyle: GoogleFonts.nunitoSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: AppColors.gold, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSM),
          ),
          textStyle: GoogleFonts.nunitoSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSM),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSM),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSM),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        hintStyle: GoogleFonts.nunitoSans(
          color: AppColors.textLight,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.creamDark,
        selectedColor: AppColors.navy,
        labelStyle: GoogleFonts.nunitoSans(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSM),
          side: const BorderSide(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // Display — Cormorant Garamond (serif headers)
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.15,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.2,
      ),
      displaySmall: GoogleFonts.cormorantGaramond(
        fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.25,
      ),

      // Headline
      headlineLarge: GoogleFonts.cormorantGaramond(
        fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.navy,
      ),
      headlineMedium: GoogleFonts.cormorantGaramond(
        fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.navy,
      ),
      headlineSmall: GoogleFonts.nunitoSans(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navy,
      ),

      // Title
      titleLarge: GoogleFonts.nunitoSans(
        fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.nunitoSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.nunitoSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),

      // Body — Nunito Sans
      bodyLarge: GoogleFonts.nunitoSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.7,
      ),
      bodyMedium: GoogleFonts.nunitoSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.7,
      ),
      bodySmall: GoogleFonts.nunitoSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.6,
      ),

      // Label
      labelLarge: GoogleFonts.nunitoSans(
        fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.nunitoSans(
        fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.nunitoSans(
        fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: AppColors.textSecondary,
      ),
    );
  }
}
