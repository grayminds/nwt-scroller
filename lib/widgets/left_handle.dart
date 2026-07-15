import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/scroll_theme.dart';

/// Left scroll handle — tap to collapse.
/// Drag-to-move is handled natively by the forked flutter_overlay_window
/// plugin using screen-space coordinates (getRawX/getRawY), so there is
/// no pointer feedback loop or amplification.  History lives in the config
/// app only; the overlay has no history popup.
class LeftHandle extends StatefulWidget {
  final ScrollTheme theme;
  final double width;
  final VoidCallback onTap;

  const LeftHandle({
    super.key,
    required this.theme,
    required this.width,
    required this.onTap,
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
        // Tap to collapse.  The time gate is loose (500 ms) so a slow,
        // deliberate press still registers; the distance threshold rejects
        // drags.
        if (elapsed.inMilliseconds < 500 && dist < 15) {
          widget.onTap();
        }
        _pointerDownTime = null;
        _pointerDownPos = null;
      },
      // The transparent padding sits inside the opaque Listener, so the whole
      // handle column stays tappable while the visible knob keeps a small
      // inset.  This widens the effective hit target on a narrow handle.
      child: SizedBox(
        width: widget.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
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
