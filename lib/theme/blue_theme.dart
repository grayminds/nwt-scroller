import 'package:flutter/material.dart';
import 'scroll_theme.dart';

class BlueTheme extends ScrollTheme {
  @override
  String get name => 'blue';
  @override
  Color get background => const Color(0xFF4A6DA7);
  @override
  Color get surface => const Color(0xFF3B5998);
  @override
  Color get textPrimary => const Color(0xFFFFFFFF);
  @override
  Color get textSecondary => const Color(0xFFD0DFEF);
  @override
  Color get accent => const Color(0xFF4A6DA7);
  @override
  Color get handleColor => const Color(0xFF3B5998);
  @override
  Color get knobTint => const Color(0xFFB0C4DE);
  @override
  Color get divider => const Color(0xFF6A8EC4);
  @override
  Color get pickerHighlight => const Color(0x404A6DA7);
}
