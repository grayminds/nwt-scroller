import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/overlay_service.dart';
import '../theme/scroll_theme.dart';

/// Left scroll handle — tap to collapse, drag to move overlay, swipe up for history.
/// Uses raw Listener instead of GestureDetector to avoid gesture arena delays
/// that cause jittery movement.
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
  // Overlay position cached eagerly; refreshed after each drag ends
  double _cachedOverlayX = 0;
  double _cachedOverlayY = 0;

  // Drag-start snapshot — frozen for the entire drag gesture
  double _dragStartOverlayX = 0;
  double _dragStartOverlayY = 0;
  Offset? _pointerStartLocal;
  DateTime? _pointerDownTime;
  bool _isDragging = false;

  // Accumulated overlay displacement — compensates for coordinate shift
  double _displacementX = 0;
  double _displacementY = 0;

  // Throttle: track latest desired position, send when previous completes
  bool _moveInFlight = false;
  double? _pendingX;
  double? _pendingY;

  @override
  void initState() {
    super.initState();
    _cachePosition();
  }

  Future<void> _cachePosition() async {
    try {
      final pos = await OverlayService.getPosition();
      _cachedOverlayX = pos.x;
      _cachedOverlayY = pos.y;
    } catch (_) {}
  }

  void _sendMove(double x, double y) {
    if (_moveInFlight) {
      _pendingX = x;
      _pendingY = y;
      return;
    }
    _moveInFlight = true;
    OverlayService.moveOverlay(x, y).then((_) {
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
        _pendingX = null;
        _pendingY = null;
        _displacementX = 0;
        _displacementY = 0;
        // Snapshot the cached position — frozen for the entire drag
        _dragStartOverlayX = _cachedOverlayX;
        _dragStartOverlayY = _cachedOverlayY;
      },
      onPointerMove: (event) {
        if (_pointerStartLocal == null) return;

        // Compensate for overlay coordinate shift: local coords shift by
        // -displacement when the overlay moves, so add displacement back.
        final screenDx =
            event.position.dx - _pointerStartLocal!.dx + _displacementX;
        final screenDy =
            event.position.dy - _pointerStartLocal!.dy + _displacementY;

        if (!_isDragging && (screenDx.abs() + screenDy.abs()) > 8) {
          _isDragging = true;
        }
        if (_isDragging) {
          _displacementX = screenDx;
          _displacementY = screenDy;
          _sendMove(
              _dragStartOverlayX + screenDx, _dragStartOverlayY + screenDy);
        }
      },
      onPointerUp: (event) {
        if (!_isDragging && _pointerDownTime != null) {
          final elapsed = DateTime.now().difference(_pointerDownTime!);
          if (elapsed.inMilliseconds < 350) {
            final dy =
                event.position.dy - (_pointerStartLocal?.dy ?? 0) + _displacementY;
            if (dy < -30) {
              widget.onSwipeUp();
            } else {
              widget.onTap();
            }
          }
        }
        // After drag ends, refresh cache with actual current position
        if (_isDragging) {
          _cachePosition();
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
