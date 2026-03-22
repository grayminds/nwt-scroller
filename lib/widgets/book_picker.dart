import 'package:flutter/cupertino.dart';
import '../models/bible_data.dart';
import '../services/config_service.dart';
import '../theme/scroll_theme.dart';

class BookPicker extends StatefulWidget {
  final List<BibleBook> books;
  final FixedExtentScrollController controller;
  final NameLength nameLength;
  final double fontSize;
  final double itemExtent;
  final ScrollTheme theme;
  final ValueChanged<int> onSelectedItemChanged;
  final ValueChanged<int> onTap;

  const BookPicker({
    super.key,
    required this.books,
    required this.controller,
    required this.nameLength,
    required this.fontSize,
    required this.itemExtent,
    required this.theme,
    required this.onSelectedItemChanged,
    required this.onTap,
  });

  @override
  State<BookPicker> createState() => _BookPickerState();
}

class _BookPickerState extends State<BookPicker> {
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
        children: widget.books.map((book) {
          final label = switch (widget.nameLength) {
            NameLength.short => book.abbr,
            NameLength.medium => book.abbrMed,
            NameLength.long => book.name,
          };
          return Center(
            child: Text(
              label,
              style: TextStyle(
                color: widget.theme.textPrimary.withValues(alpha: 0.85),
                fontSize: widget.fontSize - 1,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }
}
