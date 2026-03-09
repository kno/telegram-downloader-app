import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    _isDark = await _storage.isDarkMode();
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    await _storage.setDarkMode(_isDark);
    notifyListeners();
  }
}
