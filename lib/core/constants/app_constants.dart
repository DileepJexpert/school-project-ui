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

/// Single source of truth for class/section values stored in MongoDB.
///
/// Format rules (must be consistent across Admission, Fee Setup, Fee Collection):
///   • Pre-primary (Nursery, LKG, UKG)  → stored as-is  e.g. "Nursery"
///   • Class 1–12                        → "Class X - A" / "Class X - B"
///
/// Never hard-code this list in individual screens — always use SchoolConstants.
class SchoolConstants {
  SchoolConstants._();

  /// Base class labels (no section suffix).
  static const List<String> baseClasses = [
    'Nursery', 'LKG', 'UKG',
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6',
    'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12',
  ];

  /// Classes that do NOT have sections (pre-primary).
  static const List<String> noSectionClasses = ['Nursery', 'LKG', 'UKG'];

  /// Available sections for Class 1–12.
  static const List<String> sections = ['A', 'B'];

  /// Full flat list of all class+section combinations as stored in MongoDB.
  /// Pre-primary classes appear once (no section).
  /// Class 1–12 appear twice (one entry per section).
  static List<String> get allClasses => [
        'Nursery',
        'LKG',
        'UKG',
        for (int i = 1; i <= 12; i++)
          for (final s in sections) 'Class $i - $s',
      ];

  /// Build the stored className from a base class and section.
  /// Pre-primary → returns baseClass unchanged.
  /// Others       → returns "Class X - A" format.
  static String buildClassName(String baseClass, String section) {
    if (noSectionClasses.contains(baseClass)) return baseClass;
    return '$baseClass - $section';
  }

  /// Parse a stored className back into (baseClass, section).
  /// "Class 5 - B" → ('Class 5', 'B')
  /// "Nursery"     → ('Nursery', 'A')   (section 'A' is default for pre-primary)
  static (String, String) parseClassName(String className) {
    final parts = className.split(' - ');
    if (parts.length >= 2) {
      final base = parts[0].trim();
      final sec = parts[1].trim();
      if (baseClasses.contains(base) && sections.contains(sec)) {
        return (base, sec);
      }
    }
    // Legacy or pre-primary value — return as-is with default section
    final base = baseClasses.contains(className) ? className : baseClasses.first;
    return (base, sections.first);
  }
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
