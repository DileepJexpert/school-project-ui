import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();
  static const _preferenceKey = 'app_theme_preset';

  AppThemePreset _preset = AppThemePreset.modern;

  AppThemePreset get preset => _preset;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_preferenceKey);
    _preset = AppThemePreset.values.firstWhere(
      (value) => value.name == saved,
      orElse: () => AppThemePreset.modern,
    );
  }

  Future<void> setPreset(AppThemePreset preset) async {
    if (_preset == preset) return;
    _preset = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, preset.name);
  }
}
