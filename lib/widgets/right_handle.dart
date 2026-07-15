import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/scroll_theme.dart';

/// Right scroll handle — tap to open the config app.
/// The left and right handles are mirror halves of the same compass, but they
/// do opposite things (collapse vs open settings).  A faint, low-alpha gear
/// glyph overlaid on the right knob differentiates it so the user can tell the
/// two apart at a glance.
class RightHandle extends StatelessWidget {
  final ScrollTheme theme;
  final double width;
  final VoidCallback onTap;

  const RightHandle({
    super.key,
    required this.theme,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // The transparent padding sits inside the opaque hit region, so the whole
      // handle column stays tappable while the visible knob keeps a small
      // inset.  This widens the effective hit target on a narrow handle.
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 1),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                'assets/svg/knob_right.svg',
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  theme.knobTint,
                  BlendMode.modulate,
                ),
              ),
              // Faint gear glyph marks this as the settings handle.
              FractionallySizedBox(
                widthFactor: 0.5,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Icon(
                    Icons.settings,
                    color: theme.textPrimary.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
