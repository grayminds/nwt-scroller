import 'package:flutter/material.dart';
import 'scroll_theme.dart';

class SilverTheme extends ScrollTheme {
  @override
  String get name => 'silver';
  @override
  Color get background => const Color(0xFFD0D0D6);
  @override
  Color get surface => const Color(0xFFB8B8C0);
  @override
  Color get textPrimary => const Color(0xFF1A1A1E);
  @override
  Color get textSecondary => const Color(0xFF58585C);
  @override
  Color get accent => const Color(0xFF3A3A3E);
  @override
  Color get handleColor => const Color(0xFF2E2E32);
  @override
  Color get knobTint => const Color(0xFF707078); // cool steel gray
  @override
  Color get divider => const Color(0xFF9A9AA0);
  @override
  Color get pickerHighlight => const Color(0x40D0D0D6);
}
