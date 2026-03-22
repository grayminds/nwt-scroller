import 'dart:ui' as ui;

class ScreenService {
  /// Get the real device screen size, not the overlay window size.
  /// Uses Display API which reports actual screen dimensions
  /// even from an overlay engine where views.first is the overlay window.
  static ({double width, double height}) getScreenSize() {
    // Try Display API first — gives real screen size even in overlay engine
    final displays = ui.PlatformDispatcher.instance.displays;
    if (displays.isNotEmpty) {
      final display = displays.first;
      return (
        width: display.size.width / display.devicePixelRatio,
        height: display.size.height / display.devicePixelRatio,
      );
    }
    // Fallback: view size (will be overlay window size in overlay engine)
    final view = ui.PlatformDispatcher.instance.views.first;
    final physicalSize = view.physicalSize;
    final ratio = view.devicePixelRatio;
    return (
      width: physicalSize.width / ratio,
      height: physicalSize.height / ratio,
    );
  }
}
