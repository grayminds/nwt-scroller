import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'haptic_service.dart';

/// 0 = short (Ge, Ex), 1 = medium (Gen., Ex.), 2 = long (Genesis, Exodus)
enum NameLength { short, medium, long }

/// Overlay visual theme.  Serialized by [Enum.name] so the stored value stays
/// stable and human-readable across releases.
enum ScrollThemeId { parchment, blue, silver }

/// Overlay interaction style.  fullWheel shows five rows around the selection
/// (legacy stored value 1).  minimalFade shows a taller wheel with more rows
/// (legacy stored value 2).  Serialized by [Enum.name]; the legacy integer
/// values are still read for backward compatibility.
enum InteractionStyle { fullWheel, minimalFade }

/// Parse a stored theme value.  Falls back to parchment and warns loudly on an
/// unknown value rather than silently guessing.
ScrollThemeId _parseThemeId(Object? raw) {
  if (raw is String) {
    for (final id in ScrollThemeId.values) {
      if (id.name == raw) return id;
    }
    debugPrint('ConfigService: unknown theme "$raw", using parchment.');
  }
  return ScrollThemeId.parchment;
}

/// Parse a stored interaction style.  Accepts the new name form and the legacy
/// integer form (1, 2).  Falls back to fullWheel and warns loudly on an
/// unknown value.
InteractionStyle _parseInteractionStyle(Object? raw) {
  if (raw is InteractionStyle) return raw;
  if (raw is String) {
    for (final style in InteractionStyle.values) {
      if (style.name == raw) return style;
    }
    debugPrint(
        'ConfigService: unknown interaction style "$raw", using fullWheel.');
  } else if (raw is int) {
    return raw == 2 ? InteractionStyle.minimalFade : InteractionStyle.fullWheel;
  }
  return InteractionStyle.fullWheel;
}

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
  ScrollThemeId theme = ScrollThemeId.parchment;
  double overlayScale = 1.0;
  double fontSize = 14.0;
  double widthScale = 1.0;
  double heightScale = 1.0;
  String language = 'English';
  double selectionBarHeight = 1.0;
  InteractionStyle interactionStyle = InteractionStyle.fullWheel;
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
    // The first getInstance() call in an engine already reads a fresh copy
    // from disk, and load() runs once per engine cold start, so an explicit
    // reload() here is redundant.  Config changes propagate to the overlay
    // engine through shareData()/applyFromMap, not through a disk re-read, so
    // dropping the reload does not break cross-engine propagation.
    hapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;
    final intensityIdx = (prefs.getInt(_hapticIntensityKey) ?? 0)
        .clamp(0, HapticIntensity.values.length - 1);
    hapticIntensity = HapticIntensity.values[intensityIdx];
    final nlIdx = (prefs.getInt(_nameLengthKey) ?? 1)
        .clamp(0, NameLength.values.length - 1);
    nameLength = NameLength.values[nlIdx];
    theme = _parseThemeId(prefs.getString(_themeKey));
    overlayScale = (prefs.getDouble(_overlayScaleKey) ?? 1.0).clamp(0.8, 1.5);
    fontSize = (prefs.getDouble(_fontSizeKey) ?? 14.0).clamp(10.0, 32.0);
    widthScale = (prefs.getDouble(_widthScaleKey) ?? 1.0).clamp(0.5, 2.0);
    heightScale = (prefs.getDouble(_heightScaleKey) ?? 1.0).clamp(0.5, 2.0);
    language = prefs.getString(_languageKey) ?? 'English';
    selectionBarHeight =
        (prefs.getDouble(_selectionBarHeightKey) ?? 1.0).clamp(0.5, 2.0);
    interactionStyle = _parseInteractionStyle(prefs.get(_interactionStyleKey));
    overlayOpacity =
        (prefs.getDouble(_overlayOpacityKey) ?? 0.75).clamp(0.4, 1.0);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticEnabledKey, hapticEnabled);
    await prefs.setInt(_hapticIntensityKey, hapticIntensity.index);
    await prefs.setInt(_nameLengthKey, nameLength.index);
    await prefs.setString(_themeKey, theme.name);
    await prefs.setDouble(_overlayScaleKey, overlayScale);
    await prefs.setDouble(_fontSizeKey, fontSize);
    await prefs.setDouble(_widthScaleKey, widthScale);
    await prefs.setDouble(_heightScaleKey, heightScale);
    await prefs.setString(_languageKey, language);
    await prefs.setDouble(_selectionBarHeightKey, selectionBarHeight);
    await prefs.setString(_interactionStyleKey, interactionStyle.name);
    await prefs.setDouble(_overlayOpacityKey, overlayOpacity);
  }

  Map<String, dynamic> toMap() {
    return {
      'type': 'config',
      'hapticEnabled': hapticEnabled,
      'hapticIntensity': hapticIntensity.index,
      'nameLength': nameLength.index,
      'theme': theme.name,
      'overlayScale': overlayScale,
      'fontSize': fontSize,
      'widthScale': widthScale,
      'heightScale': heightScale,
      'language': language,
      'selectionBarHeight': selectionBarHeight,
      'interactionStyle': interactionStyle.name,
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
    final themeRaw = map['theme'];
    if (themeRaw != null) theme = _parseThemeId(themeRaw);
    // Clamp map-based values with the same ranges as load(), so a stale or
    // corrupted push cannot render the overlay with unbounded sizes.
    overlayScale =
        (map['overlayScale'] as num?)?.toDouble().clamp(0.8, 1.5) ??
            overlayScale;
    fontSize =
        (map['fontSize'] as num?)?.toDouble().clamp(10.0, 32.0) ?? fontSize;
    widthScale =
        (map['widthScale'] as num?)?.toDouble().clamp(0.5, 2.0) ?? widthScale;
    heightScale =
        (map['heightScale'] as num?)?.toDouble().clamp(0.5, 2.0) ?? heightScale;
    language = map['language'] as String? ?? language;
    selectionBarHeight =
        (map['selectionBarHeight'] as num?)?.toDouble().clamp(0.5, 2.0) ??
            selectionBarHeight;
    final styleRaw = map['interactionStyle'];
    if (styleRaw != null) interactionStyle = _parseInteractionStyle(styleRaw);
    overlayOpacity =
        (map['overlayOpacity'] as num?)?.toDouble().clamp(0.4, 1.0) ??
            overlayOpacity;
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

  Future<void> setTheme(ScrollThemeId value) async {
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
