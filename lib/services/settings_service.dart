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
  Future<SharedPreferences> get preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> init() async {
    final prefs = await preferences;
    _showMoveHints = prefs.getBool('show_move_hints') ?? true;
    _fastAiMoves = prefs.getBool('fast_ai') ?? false;
    _hapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
    final themeModeIndex = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode =
        ThemeMode.values[themeModeIndex.clamp(0, ThemeMode.values.length - 1)];
  }

  Future<void> setShowMoveHints(bool v) async {
    _showMoveHints = v;
    await (await preferences).setBool('show_move_hints', v);
    notifyListeners();
  }

  Future<void> setFastAiMoves(bool v) async {
    _fastAiMoves = v;
    await (await preferences).setBool('fast_ai', v);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool v) async {
    _hapticsEnabled = v;
    await (await preferences).setBool('haptics_enabled', v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await (await preferences).setInt('theme_mode', mode.index);
    notifyListeners();
  }
}
