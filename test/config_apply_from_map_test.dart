import 'package:flutter_test/flutter_test.dart';
import 'package:nwt_scroller/services/config_service.dart';

/// Tests for ConfigService.applyFromMap clamping (alpha review item 2.4).
///
/// applyFromMap is a pure in-memory transform over a config push map, so it
/// needs no SharedPreferences seam.  A stale or corrupted push must not render
/// the overlay with unbounded sizes, so applyFromMap must clamp with the same
/// ranges that load() uses.
void main() {
  group('ConfigService.applyFromMap clamping', () {
    test('values above the max clamp down to the max', () {
      final config = ConfigService();
      config.applyFromMap({
        'overlayScale': 5.0,
        'fontSize': 200.0,
        'widthScale': 9.0,
        'heightScale': 9.0,
        'selectionBarHeight': 9.0,
        'overlayOpacity': 3.0,
        'interactionStyle': 9,
      });

      expect(config.overlayScale, 1.5);
      expect(config.fontSize, 32.0);
      expect(config.widthScale, 2.0);
      expect(config.heightScale, 2.0);
      expect(config.selectionBarHeight, 2.0);
      expect(config.overlayOpacity, 1.0);
      // An unknown legacy integer falls back to the safe default.
      expect(config.interactionStyle, InteractionStyle.fullWheel);
    });

    test('values below the min clamp up to the min', () {
      final config = ConfigService();
      config.applyFromMap({
        'overlayScale': 0.1,
        'fontSize': 1.0,
        'widthScale': 0.01,
        'heightScale': 0.01,
        'selectionBarHeight': 0.01,
        'overlayOpacity': 0.05,
        'interactionStyle': 0,
      });

      expect(config.overlayScale, 0.8);
      expect(config.fontSize, 10.0);
      expect(config.widthScale, 0.5);
      expect(config.heightScale, 0.5);
      expect(config.selectionBarHeight, 0.5);
      // Opacity floor is 0.4 (alpha review item 2.3).
      expect(config.overlayOpacity, 0.4);
      expect(config.interactionStyle, InteractionStyle.fullWheel);
    });

    test('the opacity floor is 0.4, not the old 0.1', () {
      final config = ConfigService();
      config.applyFromMap({'overlayOpacity': 0.1});
      expect(config.overlayOpacity, 0.4);
    });

    test('in-range values pass through unchanged', () {
      final config = ConfigService();
      config.applyFromMap({
        'overlayScale': 1.2,
        'fontSize': 18.0,
        'widthScale': 1.3,
        'heightScale': 0.9,
        'selectionBarHeight': 1.5,
        'overlayOpacity': 0.6,
        'interactionStyle': 2,
      });

      expect(config.overlayScale, 1.2);
      expect(config.fontSize, 18.0);
      expect(config.widthScale, 1.3);
      expect(config.heightScale, 0.9);
      expect(config.selectionBarHeight, 1.5);
      expect(config.overlayOpacity, 0.6);
      // Legacy integer 2 maps to minimalFade.
      expect(config.interactionStyle, InteractionStyle.minimalFade);
    });

    test('missing keys leave the current values untouched', () {
      final config = ConfigService();
      config.overlayScale = 1.1;
      config.fontSize = 20.0;
      config.overlayOpacity = 0.7;
      config.interactionStyle = InteractionStyle.minimalFade;

      config.applyFromMap({'theme': 'silver'});

      expect(config.theme, ScrollThemeId.silver);
      expect(config.overlayScale, 1.1);
      expect(config.fontSize, 20.0);
      expect(config.overlayOpacity, 0.7);
      expect(config.interactionStyle, InteractionStyle.minimalFade);
    });

    test('integer-typed numeric pushes are still clamped', () {
      final config = ConfigService();
      // A push can arrive with int-typed numbers (for example over a platform
      // channel), so the num cast plus clamp must handle them.
      config.applyFromMap({
        'overlayScale': 3,
        'fontSize': 4,
      });

      expect(config.overlayScale, 1.5);
      expect(config.fontSize, 10.0);
    });

    test('theme and interaction style parse by name, unknown falls back', () {
      final config = ConfigService();
      config.applyFromMap({
        'theme': 'blue',
        'interactionStyle': 'minimalFade',
      });
      expect(config.theme, ScrollThemeId.blue);
      expect(config.interactionStyle, InteractionStyle.minimalFade);

      // An unknown name falls back to the safe default rather than guessing.
      config.applyFromMap({
        'theme': 'chartreuse',
        'interactionStyle': 'wiggle',
      });
      expect(config.theme, ScrollThemeId.parchment);
      expect(config.interactionStyle, InteractionStyle.fullWheel);
    });
  });
}
