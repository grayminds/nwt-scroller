import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/overlay_service.dart';
import '../theme/scroll_theme.dart';

class CollapsedScroll extends StatefulWidget {
  final ScrollTheme theme;
  final VoidCallback onTap;

  const CollapsedScroll({
    super.key,
    required this.theme,
    required this.onTap,
  });

  @override
  State<CollapsedScroll> createState() => _CollapsedScrollState();
}

class _CollapsedScrollState extends State<CollapsedScroll> {
  double _lastX = 0;
  double _lastY = 0;

  @override
  void initState() {
    super.initState();
    _cachePosition();
  }

  Future<void> _cachePosition() async {
    try {
      final pos = await OverlayService.getPosition();
      _lastX = pos.x;
      _lastY = pos.y;
    } catch (_) {}
  }

  Future<void> _handleTap() async {
    try {
      final pos = await OverlayService.getPosition();
      final dx = (pos.x - _lastX).abs();
      final dy = (pos.y - _lastY).abs();
      _lastX = pos.x;
      _lastY = pos.y;
      if (dx < 25 && dy < 25) {
        widget.onTap();
      }
    } catch (_) {
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SizedBox.expand(
        child: SvgPicture.asset(
          'assets/svg/compass_rose.svg',
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(
            widget.theme.knobTint,
            BlendMode.modulate,
          ),
        ),
      ),
    );
  }
}
