import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {

  bool isDark = true;
  bool isLoaded = false; // 👈 مهم

  ThemeMode get currentMode =>
      isDark ? ThemeMode.dark : ThemeMode.light;

  /// LOAD FROM STORAGE
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool("isDark") ?? true;
    isLoaded = true;
    notifyListeners();
  }

  /// TOGGLE + SAVE
  Future<void> toggleTheme() async {
    isDark = !isDark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isDark", isDark);

    notifyListeners();
  }

  /// SET FIRST TIME
  Future<void> setTheme(bool dark) async {
    isDark = dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isDark", isDark);

    notifyListeners();
  }
}