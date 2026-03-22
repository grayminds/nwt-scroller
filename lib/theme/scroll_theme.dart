import 'package:flutter/material.dart';

abstract class ScrollTheme {
  String get name;
  Color get background;
  Color get surface;
  Color get textPrimary;
  Color get textSecondary;
  Color get accent;
  Color get handleColor;
  Color get knobTint;
  Color get divider;
  Color get pickerHighlight;

  LinearGradient get bodyGradient => LinearGradient(
        colors: [surface.withValues(alpha: 0.95), background.withValues(alpha: 0.95)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}
