import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final savedTheme = await _storage.read(key: _themeKey);
      if (savedTheme != null) {
        switch (savedTheme) {
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          default:
            _themeMode = ThemeMode.system;
        }
      }
    } catch (e) {
      // Default to system theme on error
      _themeMode = ThemeMode.system;
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();

    try {
      String themeString;
      switch (mode) {
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.light:
          themeString = 'light';
          break;
        default:
          themeString = 'system';
      }
      await _storage.write(key: _themeKey, value: themeString);
    } catch (e) {
      // Silently fail - theme is still applied in memory
    }
  }

  Future<void> setDarkMode() => setThemeMode(ThemeMode.dark);
  Future<void> setLightMode() => setThemeMode(ThemeMode.light);
  Future<void> setSystemMode() => setThemeMode(ThemeMode.system);

  /// Toggle between light and dark mode (ignores system mode in toggle)
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setLightMode();
    } else {
      await setDarkMode();
    }
  }

  String get themeModeLabel {
    switch (_themeMode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      default:
        return 'System';
    }
  }

  IconData get themeModeIcon {
    switch (_themeMode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      default:
        return Icons.brightness_auto;
    }
  }
}
