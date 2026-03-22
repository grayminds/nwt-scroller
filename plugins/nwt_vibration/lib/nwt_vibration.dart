import 'package:flutter/services.dart';

class NwtVibration {
  static const _channel = MethodChannel('nwt_vibration');

  /// Vibrate with given duration (ms) and amplitude (1-255).
  static Future<void> vibrate({int duration = 20, int amplitude = 128}) async {
    try {
      await _channel.invokeMethod('vibrate', {
        'duration': duration,
        'amplitude': amplitude,
      });
    } catch (_) {}
  }

  /// Launch a URL via native Android Intent with FLAG_ACTIVITY_NEW_TASK.
  /// Works from Service context (overlay engine).
  static Future<bool> launchUrl(String url) async {
    try {
      final result = await _channel.invokeMethod('launchUrl', {'url': url});
      return result == true;
    } catch (_) {
      return false;
    }
  }
}
