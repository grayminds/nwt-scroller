import 'package:nwt_vibration/nwt_vibration.dart';

enum HapticIntensity { light, medium, heavy }

class HapticService {
  bool enabled;
  HapticIntensity intensity;

  DateTime? _lastTick;

  HapticService({this.enabled = true, this.intensity = HapticIntensity.light});

  /// Tick with velocity-proportional intensity.
  /// Faster scrolling = lighter individual ticks, slower = stronger.
  void tick() {
    if (!enabled) return;

    final now = DateTime.now();
    double speedFactor = 1.0;
    if (_lastTick != null) {
      final ms = now.difference(_lastTick!).inMilliseconds;
      // ms between ticks: <40ms = very fast, >200ms = slow
      speedFactor = (ms / 150).clamp(0.3, 1.5);
    }
    _lastTick = now;

    switch (intensity) {
      case HapticIntensity.light:
        final amp = (50 * speedFactor).round().clamp(20, 80);
        NwtVibration.vibrate(duration: 10, amplitude: amp);
      case HapticIntensity.medium:
        final amp = (100 * speedFactor).round().clamp(40, 160);
        NwtVibration.vibrate(duration: 15, amplitude: amp);
      case HapticIntensity.heavy:
        final amp = (160 * speedFactor).round().clamp(80, 255);
        NwtVibration.vibrate(duration: 25, amplitude: amp);
    }
  }

  void selectionClick() {
    if (!enabled) return;
    NwtVibration.vibrate(duration: 10, amplitude: 60);
  }
}
