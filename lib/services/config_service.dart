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
  static const _widthScaleKey = 'width_scale';
  static const _heightScaleKey = 'height_scale';
  static const _languageKey = 'language';
  static const _selectionBarHeightKey = 'selection_bar_height';
  static const _interactionStyleKey = 'interaction_style';
  static const _overlayOpacityKey = 'overlay_opacity';

  bool hapticEnabled = true;
  HapticIntensity hapticIntensity = HapticIntensity.light;
  NameLength nameLength = NameLength.medium;
  String theme = 'parchment';
  double overlayScale = 1.0;
  double fontSize = 14.0;
  double widthScale = 1.0;
  double heightScale = 1.0;
  String language = 'English';
  double selectionBarHeight = 1.0;
  int interactionStyle = 1;
  double overlayOpacity = 0.75;
  double screenWidth = 0;
  double screenHeight = 0;

  static const supportedLanguages = [
    'English',
    'Spanish',
    'Russian',
    'French',
    'Italian',
  ];

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
    fontSize = (prefs.getDouble(_fontSizeKey) ?? 14.0).clamp(10.0, 32.0);
    widthScale = (prefs.getDouble(_widthScaleKey) ?? 1.0).clamp(0.5, 2.0);
    heightScale = (prefs.getDouble(_heightScaleKey) ?? 1.0).clamp(0.5, 2.0);
    language = prefs.getString(_languageKey) ?? 'English';
    selectionBarHeight =
        (prefs.getDouble(_selectionBarHeightKey) ?? 1.0).clamp(0.5, 2.0);
    interactionStyle = (prefs.getInt(_interactionStyleKey) ?? 1).clamp(1, 2);
    overlayOpacity =
        (prefs.getDouble(_overlayOpacityKey) ?? 0.75).clamp(0.1, 1.0);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticEnabledKey, hapticEnabled);
    await prefs.setInt(_hapticIntensityKey, hapticIntensity.index);
    await prefs.setInt(_nameLengthKey, nameLength.index);
    await prefs.setString(_themeKey, theme);
    await prefs.setDouble(_overlayScaleKey, overlayScale);
    await prefs.setDouble(_fontSizeKey, fontSize);
    await prefs.setDouble(_widthScaleKey, widthScale);
    await prefs.setDouble(_heightScaleKey, heightScale);
    await prefs.setString(_languageKey, language);
    await prefs.setDouble(_selectionBarHeightKey, selectionBarHeight);
    await prefs.setInt(_interactionStyleKey, interactionStyle);
    await prefs.setDouble(_overlayOpacityKey, overlayOpacity);
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
      'widthScale': widthScale,
      'heightScale': heightScale,
      'language': language,
      'selectionBarHeight': selectionBarHeight,
      'interactionStyle': interactionStyle,
      'overlayOpacity': overlayOpacity,
      'screenWidth': screenWidth,
      'screenHeight': screenHeight,
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
    widthScale = (map['widthScale'] as num?)?.toDouble() ?? widthScale;
    heightScale = (map['heightScale'] as num?)?.toDouble() ?? heightScale;
    language = map['language'] as String? ?? language;
    selectionBarHeight =
        (map['selectionBarHeight'] as num?)?.toDouble() ?? selectionBarHeight;
    interactionStyle =
        (map['interactionStyle'] as int?)?.clamp(1, 2) ?? interactionStyle;
    overlayOpacity =
        (map['overlayOpacity'] as num?)?.toDouble().clamp(0.1, 1.0) ?? overlayOpacity;
    final sw = (map['screenWidth'] as num?)?.toDouble();
    if (sw != null && sw > 0) screenWidth = sw;
    final sh = (map['screenHeight'] as num?)?.toDouble();
    if (sh != null && sh > 0) screenHeight = sh;
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
    fontSize = value.clamp(10.0, 32.0);
    await save();
  }

  Future<void> setWidthScale(double value) async {
    widthScale = value.clamp(0.5, 2.0);
    await save();
  }

  Future<void> setHeightScale(double value) async {
    heightScale = value.clamp(0.5, 2.0);
    await save();
  }

  Future<void> setLanguage(String value) async {
    language = value;
    await save();
  }

  Future<void> setSelectionBarHeight(double value) async {
    selectionBarHeight = value.clamp(0.5, 2.0);
    await save();
  }
}
