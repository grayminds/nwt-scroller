import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/overlay_service.dart';
import '../theme/scroll_theme.dart';

/// Left scroll handle — tap to collapse, drag to move overlay, swipe up for history.
/// Uses raw Listener instead of GestureDetector to avoid gesture arena delays.
class LeftHandle extends StatefulWidget {
  final ScrollTheme theme;
  final double width;
  final double screenWidth;
  final double screenHeight;
  final double overlayWidth;
  final double overlayHeight;
  final VoidCallback onTap;
  final VoidCallback onSwipeUp;

  const LeftHandle({
    super.key,
    required this.theme,
    required this.width,
    required this.screenWidth,
    required this.screenHeight,
    required this.overlayWidth,
    required this.overlayHeight,
    required this.onTap,
    required this.onSwipeUp,
  });

  @override
  State<LeftHandle> createState() => _LeftHandleState();
}

class _LeftHandleState extends State<LeftHandle> {
  // Drag-start snapshot — re-anchored when each move completes
  double _dragStartOverlayX = 0;
  double _dragStartOverlayY = 0;
  Offset? _pointerStartLocal;
  DateTime? _pointerDownTime;
  bool _isDragging = false;
  bool _positionReady = false;

  // Throttle: track latest desired position, send when previous completes
  bool _moveInFlight = false;
  double? _pendingX;
  double? _pendingY;

  /// Clamp position to keep overlay fully on screen.
  double _clampX(double x) {
    if (widget.screenWidth <= 0) return x;
    return x.clamp(0.0, (widget.screenWidth - widget.overlayWidth).clamp(0.0, widget.screenWidth));
  }

  double _clampY(double y) {
    if (widget.screenHeight <= 0) return y;
    return y.clamp(0.0, (widget.screenHeight - widget.overlayHeight).clamp(0.0, widget.screenHeight));
  }

  void _sendMove(double x, double y) {
    if (_moveInFlight) {
      _pendingX = x;
      _pendingY = y;
      return;
    }
    _moveInFlight = true;
    OverlayService.moveOverlay(x, y).then((_) {
      // Re-anchor: overlay is now at (x, y).
      // Keep _pointerStartLocal frozen — only update _dragStart.
      // This correctly compensates for the coordinate shift without amplification.
      _dragStartOverlayX = x;
      _dragStartOverlayY = y;
      _moveInFlight = false;
      if (_pendingX != null && _pendingY != null) {
        final px = _pendingX!;
        final py = _pendingY!;
        _pendingX = null;
        _pendingY = null;
        _sendMove(px, py);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _pointerDownTime = DateTime.now();
        _pointerStartLocal = event.position;
        _isDragging = false;
        _positionReady = false;
        _pendingX = null;
        _pendingY = null;
        // Query fresh position — don't rely on stale cache
        OverlayService.getPosition().then((pos) {
          _dragStartOverlayX = pos.x;
          _dragStartOverlayY = pos.y;
          _positionReady = true;
        }).catchError((_) {
          _positionReady = false;
        });
      },
      onPointerMove: (event) {
        if (_pointerStartLocal == null || !_positionReady) return;

        final dx = event.position.dx - _pointerStartLocal!.dx;
        final dy = event.position.dy - _pointerStartLocal!.dy;

        if (!_isDragging && (dx.abs() + dy.abs()) > 8) {
          _isDragging = true;
        }
        if (_isDragging) {
          final targetX = _clampX(_dragStartOverlayX + dx);
          final targetY = _clampY(_dragStartOverlayY + dy);
          _sendMove(targetX, targetY);
        }
      },
      onPointerUp: (event) {
        if (!_isDragging && _pointerDownTime != null) {
          final elapsed = DateTime.now().difference(_pointerDownTime!);
          if (elapsed.inMilliseconds < 350) {
            final dy = event.position.dy - (_pointerStartLocal?.dy ?? 0);
            if (dy < -30) {
              widget.onSwipeUp();
            } else {
              widget.onTap();
            }
          }
        }
        _pointerStartLocal = null;
        _pointerDownTime = null;
        _isDragging = false;
        _pendingX = null;
        _pendingY = null;
        _moveInFlight = false;
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
