import 'package:flutter/material.dart';
import 'scroll_theme.dart';

class ParchmentTheme extends ScrollTheme {
  @override
  String get name => 'parchment';
  @override
  Color get background => const Color(0xFFF5E6C8);
  @override
  Color get surface => const Color(0xFFEDD9B5);
  @override
  Color get textPrimary => const Color(0xFF5C3A1E);
  @override
  Color get textSecondary => const Color(0xFF8B6F47);
  @override
  Color get accent => const Color(0xFF8B4513);
  @override
  Color get handleColor => const Color(0xFF6B3410);
  @override
  Color get knobTint => const Color(0xFF96724E); // warm brown wood
  @override
  Color get divider => const Color(0xFFCBB896);
  @override
  Color get pickerHighlight => const Color(0x40F5E6C8);
}
