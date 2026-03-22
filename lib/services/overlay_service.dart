import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  /// Compute the unified compass display size from config values.
  /// This is THE single source of truth for all overlay sizing.
  static int compassSize(double fontSize, double overlayScale) {
    return (fontSize * 1.1 * 3.0 * overlayScale).round().clamp(36, 160);
  }

  /// Handle width = 1/3 of compass size for compact handles.
  static double handleWidth(int compassSize) {
    return compassSize / 3.0;
  }

  /// Collapsed overlay size — matches the visual compass size shown in
  /// expanded handles. Each half-SVG (24×48 viewBox, aspect 1:2) at
  /// handleWidth renders the compass at 2×handleWidth = 2/3 compassSize.
  static int collapsedDisplaySize(int compassSize) {
    return (compassSize * 2 / 3).round().clamp(24, 106);
  }

  static Future<bool> requestPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted) return true;
    await FlutterOverlayWindow.requestPermission();
    return FlutterOverlayWindow.isPermissionGranted();
  }

  static Future<void> showOverlay(int size) async {
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      height: size,
      width: size,
      alignment: OverlayAlignment.topLeft,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.none,
    );
  }

  static Future<void> setDefaultPosition(
      double screenWidth, double screenHeight, int collapsedSize) async {
    final x = (screenWidth / 3) - (collapsedSize / 2);
    final y = (screenHeight * 2 / 3) - (collapsedSize / 2);
    await FlutterOverlayWindow.moveOverlay(OverlayPosition(x, y));
  }

  static Future<OverlayPosition> getPosition() async {
    return FlutterOverlayWindow.getOverlayPosition();
  }

  static Future<void> resizeToExpanded(int width, int height) async {
    await FlutterOverlayWindow.resizeOverlay(width, height, false);
  }

  static Future<void> resizeToCollapsed(int size) async {
    await FlutterOverlayWindow.resizeOverlay(size, size, true);
  }

  static Future<void> moveOverlay(double x, double y) async {
    await FlutterOverlayWindow.moveOverlay(OverlayPosition(x, y));
  }

  static Future<void> closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  static Future<bool> isActive() async {
    return FlutterOverlayWindow.isActive();
  }

  static Future<void> shareData(dynamic data) async {
    await FlutterOverlayWindow.shareData(data);
  }

  static Stream<dynamic> get overlayListener {
    return FlutterOverlayWindow.overlayListener;
  }

  /// Enable native drag for the left zone of the expanded overlay.
  /// Uses screen-space coordinates to avoid the pointer feedback loop.
  static Future<void> enableCustomDrag(int zoneWidthPx) async {
    await FlutterOverlayWindow.setCustomDrag(true, zoneWidthPx);
  }

  static Future<void> disableCustomDrag() async {
    await FlutterOverlayWindow.setCustomDrag(false, 0);
  }
}
