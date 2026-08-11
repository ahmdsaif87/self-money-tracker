import 'package:flutter/foundation.dart';
import '../db/database.dart';

/// Theme store — mirrors src/store/useThemeStore.ts
class ThemeStore extends ChangeNotifier {
  ThemeStore._();
  static final ThemeStore instance = ThemeStore._();

  bool _isDarkMode = false;
  bool _initialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get initialized => _initialized;

  static const _themeKey = 'theme_dark';

  Future<void> initTheme() async {
    if (_initialized) return;
    final saved = await DB.instance.getSetting(_themeKey);
    if (saved != null) {
      _isDarkMode = saved == '1';
      _initialized = true;
      notifyListeners();
      return;
    }
    _initialized = true;
    await DB.instance.setSetting(_themeKey, _isDarkMode ? '1' : '0');
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await DB.instance.setSetting(_themeKey, _isDarkMode ? '1' : '0');
  }

  void setDarkMode(bool val) {
    _isDarkMode = val;
    notifyListeners();
  }
}
