import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Katasticho ERP Brand Palette (Teal-600 & Teal-500)
  static const Color navy = Color(0xFF0F8576);     // Brand Primary (Teal-600)
  static const Color navyLight = Color(0xFF14A08C); // Brand Secondary (Teal-500)
  static const Color navyDark = Color(0xFF0A5C52);  // Brand Dark
  static const Color gold = Color(0xFFB45309);      // Accent Amber
  static const Color goldLight = Color(0xFFD97706);
  static const Color goldPale = Color(0xFFFEF3E2);

  // Neutrals — Warm neutral (Katasticho ERP design system)
  static const Color cream = Color(0xFFF7F7F5);     // App Canvas (--bg-app)
  static const Color creamDark = Color(0xFFEFEFEC); // Subtle bg
  static const Color white = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E5E1);    // Border (--border)
  static const Color borderStrong = Color(0xFFD4D4CF);
  static const Color sidebarBg = Color(0xFF0F172A); // Slate-900 sidebar seed

  // Text — Warm-tinted near-black & grey
  static const Color textPrimary = Color(0xFF1A1A18);
  static const Color textSecondary = Color(0xFF5F5F59);
  static const Color textLight = Color(0xFF94948D);

  // Semantic
  static const Color success = Color(0xFF15803D);
  static const Color error = Color(0xFFBE3A34);
  static const Color warning = Color(0xFFB45309);
  static const Color info = Color(0xFF1D4ED8);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDark, navy, navyLight],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navyLight],
  );
}

class AppSizes {
  AppSizes._();

  // Padding — compact ERP density
  static const double paddingXS = 4.0;
  static const double paddingSM = 8.0;
  static const double paddingMD = 12.0;
  static const double paddingLG = 16.0;
  static const double paddingXL = 24.0;
  static const double paddingXXL = 36.0;

  // Border radius — capped at 8px per Katasticho ERP specification
  static const double radiusSM = 4.0;
  static const double radiusMD = 6.0;
  static const double radiusLG = 8.0;
  static const double radiusXL = 8.0;

  // Breakpoints
  static const double mobile = 600.0;
  static const double tablet = 900.0;
  static const double desktop = 1200.0;

  // Max content width
  static const double maxContentWidth = 1280.0;

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
    'Nursery',
    'LKG',
    'UKG',
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
    'Class 11',
    'Class 12',
  ];

  /// Classes that do NOT have sections (pre-primary).
  static const List<String> noSectionClasses = ['Nursery', 'LKG', 'UKG'];

  /// Available sections for Class 1–12.
  static const List<String> sections = ['A', 'B'];

  /// Common school subjects for dropdowns.
  static const List<String> commonSubjects = [
    'English',
    'Hindi',
    'Mathematics',
    'Science',
    'Social Studies',
    'Computer Science',
    'Physical Education',
    'Art',
    'Music',
    'Sanskrit',
    'EVS',
    'General Knowledge',
    'Moral Science',
  ];

  /// Standard fee components / heads in master data.
  static const List<String> masterFeeComponents = [
    'Tuition Fee',
    'Admission Fee',
    'Exam Fee',
    'Transport Fee',
    'Development Fee',
    'Computer Fee',
    'Library Fee',
    'Sports Fee',
    'Laboratory Fee',
    'Activity Fee',
    'Annual Fee',
    'Hostel Fee',
    'Communication Fee',
    'Uniform Fee',
    'Miscellaneous Fee',
  ];

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
    final base =
        baseClasses.contains(className) ? className : baseClasses.first;
    return (base, sections.first);
  }
}

class AppStrings {
  AppStrings._();

  static String schoolName = 'Springfield International Academy';
  static String schoolShortName = 'SIA';
  static String tagline = 'Nurturing Minds, Building Character, Inspiring Excellence';
  static String accreditation = 'Affiliated to CBSE, New Delhi';
  static String founded = '1987';
  static String phone = '+91 11 2345 6789';
  static String email = 'admissions@springfield.edu.in';
  static String address = 'Plot 12, Sector 5, Knowledge Park, New Delhi - 110001';
  static String officeHours = 'Mon - Sat: 8:00 AM - 4:00 PM';
  static String announcement = 'Admissions open for Academic Year 2026-27 from Nursery to Grade 11';
}
