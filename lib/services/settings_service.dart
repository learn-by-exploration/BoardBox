import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralised settings that all boards read. Call [init] in main() before runApp.
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  SharedPreferences? _prefs;

  bool _showMoveHints = true;
  bool _fastAiMoves = false;
  bool _hapticsEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;

  bool get showMoveHints => _showMoveHints;
  bool get fastAiMoves => _fastAiMoves;
  bool get hapticsEnabled => _hapticsEnabled;
  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _showMoveHints = _prefs!.getBool('show_move_hints') ?? true;
    _fastAiMoves = _prefs!.getBool('fast_ai') ?? false;
    _hapticsEnabled = _prefs!.getBool('haptics_enabled') ?? true;
    final themeModeIndex = _prefs!.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeModeIndex.clamp(0, ThemeMode.values.length - 1)];
  }

  Future<void> setShowMoveHints(bool v) async {
    _showMoveHints = v;
    await _prefs?.setBool('show_move_hints', v);
    notifyListeners();
  }

  Future<void> setFastAiMoves(bool v) async {
    _fastAiMoves = v;
    await _prefs?.setBool('fast_ai', v);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool v) async {
    _hapticsEnabled = v;
    await _prefs?.setBool('haptics_enabled', v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt('theme_mode', mode.index);
    notifyListeners();
  }
}
