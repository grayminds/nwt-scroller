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

  /// Check if a package is installed on the device.
  static Future<bool> isPackageInstalled(String packageName) async {
    try {
      final result = await _channel.invokeMethod(
          'isPackageInstalled', {'packageName': packageName});
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Bring the main app activity to the foreground.
  /// Works from overlay Service context.
  static Future<bool> openMainApp() async {
    try {
      final result = await _channel.invokeMethod('openMainApp');
      return result == true;
    } catch (_) {
      return false;
    }
  }
}
