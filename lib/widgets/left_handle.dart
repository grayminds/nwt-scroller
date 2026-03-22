import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/scroll_theme.dart';

/// Left scroll handle — tap to collapse, swipe up for history.
/// Drag-to-move is handled natively by the forked flutter_overlay_window
/// plugin using screen-space coordinates (getRawX/getRawY), so there is
/// no pointer feedback loop or amplification.
class LeftHandle extends StatefulWidget {
  final ScrollTheme theme;
  final double width;
  final VoidCallback onTap;
  final VoidCallback onSwipeUp;

  const LeftHandle({
    super.key,
    required this.theme,
    required this.width,
    required this.onTap,
    required this.onSwipeUp,
  });

  @override
  State<LeftHandle> createState() => _LeftHandleState();
}

class _LeftHandleState extends State<LeftHandle> {
  DateTime? _pointerDownTime;
  Offset? _pointerDownPos;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _pointerDownTime = DateTime.now();
        _pointerDownPos = event.position;
      },
      onPointerUp: (event) {
        if (_pointerDownTime == null || _pointerDownPos == null) return;
        final elapsed = DateTime.now().difference(_pointerDownTime!);
        final dist = (event.position - _pointerDownPos!).distance;
        if (elapsed.inMilliseconds < 350 && dist < 15) {
          final dy = event.position.dy - _pointerDownPos!.dy;
          if (dy < -30) {
            widget.onSwipeUp();
          } else {
            widget.onTap();
          }
        }
        _pointerDownTime = null;
        _pointerDownPos = null;
      },
      child: SizedBox(
        width: widget.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: SvgPicture.asset(
            'assets/svg/knob_left.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              widget.theme.knobTint,
              BlendMode.modulate,
            ),
          ),
        ),
      ),
    );
  }
}
