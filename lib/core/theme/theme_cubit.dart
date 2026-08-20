import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import '../data/hive_database.dart';

/// Cubit managing the app's theme mode (light/dark/system).
/// Persists user preference to Hive settingsBox.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(_loadSaved());

  static ThemeMode _loadSaved() {
    final saved =
        HiveDatabase.settingsBox.get('themeMode', defaultValue: 'system');
    switch (saved) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  void setTheme(ThemeMode mode) {
    HiveDatabase.settingsBox.put('themeMode', mode.name);
    emit(mode);
  }

  void toggleDarkMode() {
    if (state == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }
}
