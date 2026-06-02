import 'package:flutter/services.dart';
import 'package:common_games/services/settings_service.dart';

/// Centralised haptics — all calls are gated on the user's haptics preference.
class HapticService {
  const HapticService._();

  /// Light tap — valid piece placement / cell selection.
  static void onMove() {
    if (SettingsService.instance.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  /// Medium — piece capture.
  static void onCapture() {
    if (SettingsService.instance.hapticsEnabled) HapticFeedback.mediumImpact();
  }

  /// Heavy — game over / win.
  static void onGameOver() {
    if (SettingsService.instance.hapticsEnabled) HapticFeedback.heavyImpact();
  }

  /// Light — selecting a piece (e.g. checkers piece tap).
  static void onSelect() {
    if (SettingsService.instance.hapticsEnabled) HapticFeedback.lightImpact();
  }
}
