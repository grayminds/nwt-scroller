import 'package:flutter/cupertino.dart';
import '../theme/scroll_theme.dart';

class ChapterPicker extends StatefulWidget {
  final int chapterCount;
  final FixedExtentScrollController controller;
  final double fontSize;
  final double itemExtent;
  final ScrollTheme theme;
  final ValueChanged<int> onSelectedItemChanged;
  final ValueChanged<int> onTap;

  const ChapterPicker({
    super.key,
    required this.chapterCount,
    required this.controller,
    required this.fontSize,
    required this.itemExtent,
    required this.theme,
    required this.onSelectedItemChanged,
    required this.onTap,
  });

  @override
  State<ChapterPicker> createState() => _ChapterPickerState();
}

class _ChapterPickerState extends State<ChapterPicker> {
  DateTime? _pointerDown;
  Offset? _pointerDownPos;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _pointerDown = DateTime.now();
        _pointerDownPos = e.localPosition;
      },
      onPointerUp: (e) {
        if (_pointerDown == null || _pointerDownPos == null) return;
        final elapsed = DateTime.now().difference(_pointerDown!);
        final dist = (e.localPosition - _pointerDownPos!).distance;
        if (elapsed.inMilliseconds < 400 && dist < 25) {
          widget.onTap(widget.controller.selectedItem);
        }
        _pointerDown = null;
        _pointerDownPos = null;
      },
      child: CupertinoPicker(
        scrollController: widget.controller,
        itemExtent: widget.itemExtent,
        diameterRatio: 1.8,
        squeeze: 0.9,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: widget.onSelectedItemChanged,
        children: List.generate(widget.chapterCount, (i) {
          return Center(
            child: Text(
              '${i + 1}',
              style: TextStyle(
                color: widget.theme.textPrimary,
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }),
      ),
    );
  }
}
