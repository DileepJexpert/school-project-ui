import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette — Navy & Gold
  static const Color navy = Color(0xFF1B3A5C);
  static const Color navyLight = Color(0xFF264D73);
  static const Color navyDark = Color(0xFF122840);
  static const Color gold = Color(0xFFC8922A);
  static const Color goldLight = Color(0xFFD4A84D);
  static const Color goldPale = Color(0xFFF5ECD7);

  // Neutrals
  static const Color cream = Color(0xFFFDFBF7);
  static const Color creamDark = Color(0xFFF5F0E8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2D9C8);

  // Text
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDark, navy, navyLight],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldLight],
  );
}

class AppSizes {
  AppSizes._();

  // Padding
  static const double paddingXS = 4.0;
  static const double paddingSM = 8.0;
  static const double paddingMD = 16.0;
  static const double paddingLG = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  // Border radius
  static const double radiusSM = 4.0;
  static const double radiusMD = 8.0;
  static const double radiusLG = 12.0;
  static const double radiusXL = 16.0;

  // Breakpoints
  static const double mobile = 600.0;
  static const double tablet = 900.0;
  static const double desktop = 1200.0;

  // Max content width
  static const double maxContentWidth = 1200.0;

  // Section padding
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(
    horizontal: paddingLG,
    vertical: paddingXXL,
  );
}

class AppStrings {
  AppStrings._();

  static const String schoolName = 'Springfield International Academy';
  static const String schoolShortName = 'SIA';
  static const String tagline = 'Nurturing Minds, Building Futures';
  static const String accreditation = 'CBSE Affiliated';
  static const String founded = '1987';
  static const String phone = '+1 (555) 234-5678';
  static const String email = 'admissions@springfieldacademy.edu';
  static const String address = '42 Heritage Lane, Springfield, IL 62704';
  static const String officeHours = 'Mon – Fri: 8:00 AM – 4:00 PM\nSat: 9:00 AM – 1:00 PM';
}
