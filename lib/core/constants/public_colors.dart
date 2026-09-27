import 'package:flutter/material.dart';

/// Bright colors used by the public website only. Admin and portal colors stay separate.
class PublicColors {
  PublicColors._();

  static const Color navy = Color(0xFF08769A);
  static const Color navyDark = Color(0xFF075B7B);
  static const Color navyLight = Color(0xFF15A7BD);
  static const Color gold = Color(0xFFB35A00);
  static const Color goldLight = Color(0xFFFFDE8A);
  static const Color goldPale = Color(0xFFFFF6E1);

  static const Color cream = Color(0xFFFFFCF3);
  static const Color creamDark = Color(0xFFFFF6E5);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFD5E9E9);

  static const Color textPrimary = Color(0xFF18344A);
  static const Color textSecondary = Color(0xFF506978);
  static const Color textLight = Color(0xFF7A929C);
  static const Color success = Color(0xFF057A65);
  static const Color error = Color(0xFFDC2626);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF075B7B), Color(0xFF08769A), Color(0xFF1499AB)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE689), Color(0xFFFFBF69)],
  );
}
