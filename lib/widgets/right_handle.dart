import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/scroll_theme.dart';

/// Right scroll handle — tap to toggle settings panel.
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
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: SvgPicture.asset(
            'assets/svg/knob_right.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(
              theme.knobTint,
              BlendMode.modulate,
            ),
          ),
        ),
      ),
    );
  }
}
