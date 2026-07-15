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

  /// Device pixel ratio for the current display.  Screen sizes throughout the
  /// app are expressed in logical pixels, so native measurements that arrive
  /// in physical pixels (for example the rotation `screenSize` push) must be
  /// divided by this value before use.  The view's ratio is reliable even in
  /// the overlay engine, where the reported view size is not.
  static double getDevicePixelRatio() {
    return ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  }
}
