import 'package:flutter/material.dart';
import 'scroll_theme.dart';

class BlueTheme extends ScrollTheme {
  @override
  String get name => 'blue';
  @override
  Color get background => const Color(0xFFE8EDF5);
  @override
  Color get surface => const Color(0xFFD0DAE8);
  @override
  Color get textPrimary => const Color(0xFF1A2A42);
  @override
  Color get textSecondary => const Color(0xFF4A6078);
  @override
  Color get accent => const Color(0xFF4A6DA7);
  @override
  Color get handleColor => const Color(0xFF365080);
  @override
  Color get knobTint => const Color(0xFF6080A8);
  @override
  Color get divider => const Color(0xFF8A9AB8);
  @override
  Color get pickerHighlight => const Color(0x40E8EDF5);
}
