import 'package:shared_preferences/shared_preferences.dart';
import 'haptic_service.dart';

/// 0 = short (Ge, Ex), 1 = medium (Gen., Ex.), 2 = long (Genesis, Exodus)
enum NameLength { short, medium, long }

class ConfigService {
  static const _hapticEnabledKey = 'haptic_enabled';
  static const _hapticIntensityKey = 'haptic_intensity';
  static const _nameLengthKey = 'name_length';
  static const _themeKey = 'theme';
  static const _overlayScaleKey = 'overlay_scale';
  static const _fontSizeKey = 'font_size';

  bool hapticEnabled = true;
  HapticIntensity hapticIntensity = HapticIntensity.light;
  NameLength nameLength = NameLength.medium;
  String theme = 'parchment';
  double overlayScale = 1.0;
  double fontSize = 14.0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    hapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;
    final intensityIdx = (prefs.getInt(_hapticIntensityKey) ?? 0)
        .clamp(0, HapticIntensity.values.length - 1);
    hapticIntensity = HapticIntensity.values[intensityIdx];
    final nlIdx = (prefs.getInt(_nameLengthKey) ?? 1)
        .clamp(0, NameLength.values.length - 1);
    nameLength = NameLength.values[nlIdx];
    theme = prefs.getString(_themeKey) ?? 'parchment';
    overlayScale = (prefs.getDouble(_overlayScaleKey) ?? 1.0).clamp(0.8, 1.5);
    fontSize = (prefs.getDouble(_fontSizeKey) ?? 14.0).clamp(10.0, 20.0);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticEnabledKey, hapticEnabled);
    await prefs.setInt(_hapticIntensityKey, hapticIntensity.index);
    await prefs.setInt(_nameLengthKey, nameLength.index);
    await prefs.setString(_themeKey, theme);
    await prefs.setDouble(_overlayScaleKey, overlayScale);
    await prefs.setDouble(_fontSizeKey, fontSize);
  }

  Map<String, dynamic> toMap() {
    return {
      'type': 'config',
      'hapticEnabled': hapticEnabled,
      'hapticIntensity': hapticIntensity.index,
      'nameLength': nameLength.index,
      'theme': theme,
      'overlayScale': overlayScale,
      'fontSize': fontSize,
    };
  }

  void applyFromMap(Map<String, dynamic> map) {
    hapticEnabled = map['hapticEnabled'] as bool? ?? hapticEnabled;
    final hIdx = map['hapticIntensity'] as int? ?? hapticIntensity.index;
    hapticIntensity =
        HapticIntensity.values[hIdx.clamp(0, HapticIntensity.values.length - 1)];
    final nlIdx = map['nameLength'] as int? ?? nameLength.index;
    nameLength =
        NameLength.values[nlIdx.clamp(0, NameLength.values.length - 1)];
    theme = map['theme'] as String? ?? theme;
    overlayScale =
        (map['overlayScale'] as num?)?.toDouble() ?? overlayScale;
    fontSize = (map['fontSize'] as num?)?.toDouble() ?? fontSize;
  }

  Future<void> setHapticEnabled(bool value) async {
    hapticEnabled = value;
    await save();
  }

  Future<void> setHapticIntensity(HapticIntensity value) async {
    hapticIntensity = value;
    await save();
  }

  Future<void> setNameLength(NameLength value) async {
    nameLength = value;
    await save();
  }

  Future<void> setTheme(String value) async {
    theme = value;
    await save();
  }

  Future<void> setOverlayScale(double value) async {
    overlayScale = value.clamp(0.8, 1.5);
    await save();
  }

  Future<void> setFontSize(double value) async {
    fontSize = value.clamp(10.0, 20.0);
    await save();
  }
}
