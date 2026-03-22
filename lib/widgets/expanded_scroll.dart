import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nwt_vibration/nwt_vibration.dart';
import '../models/bible_data.dart';
import '../models/bible_reference.dart';
import '../models/history_entry.dart';
import '../services/haptic_service.dart';
import '../services/launcher_service.dart';
import '../services/config_service.dart';
import '../services/overlay_service.dart';
import '../data/history_repository.dart';
import '../theme/scroll_theme.dart';
import 'book_picker.dart';
import 'chapter_picker.dart';
import 'verse_picker.dart';
import 'left_handle.dart';
import 'right_handle.dart';
import 'history_popup.dart';

class ExpandedScroll extends StatefulWidget {
  final List<BibleBook> books;
  final ScrollTheme theme;
  final ConfigService config;
  final HapticService haptics;
  final HistoryRepository historyRepo;
  final VoidCallback onCollapse;
  final VoidCallback onConfigChanged;
  final int initialBook;
  final int initialChapter;
  final int initialVerse;
  final void Function(int book, int chapter, int verse) onSelectionChanged;

  const ExpandedScroll({
    super.key,
    required this.books,
    required this.theme,
    required this.config,
    required this.haptics,
    required this.historyRepo,
    required this.onCollapse,
    required this.onConfigChanged,
    this.initialBook = 0,
    this.initialChapter = 0,
    this.initialVerse = 0,
    required this.onSelectionChanged,
  });

  @override
  State<ExpandedScroll> createState() => _ExpandedScrollState();
}

class _ExpandedScrollState extends State<ExpandedScroll> {
  late FixedExtentScrollController _bookController;
  late FixedExtentScrollController _chapterController;
  late FixedExtentScrollController _verseController;

  late int _selectedBook;
  late int _selectedChapter;
  late int _selectedVerse;

  bool _showHistory = false;
  List<HistoryEntry> _history = [];

  int _chapterPickerKey = 0;
  int _versePickerKey = 0;
  Timer? _autoCollapseTimer;

  BibleBook get _currentBook => widget.books[_selectedBook];
  int get _chapterCount => _currentBook.chapterCount;
  int get _verseCount => _currentBook.verseCount(_selectedChapter + 1);

  int get _compassSize =>
      OverlayService.compassSize(widget.config.overlayScale);
  double get _handleWidth => OverlayService.handleWidth(_compassSize);
  double get _itemExtent => _compassSize / 3.0;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initialBook.clamp(0, widget.books.length - 1);
    _selectedChapter = widget.initialChapter.clamp(0, _chapterCount - 1);
    _selectedVerse = widget.initialVerse.clamp(0, _verseCount - 1);
    _bookController = FixedExtentScrollController(initialItem: _selectedBook);
    _chapterController =
        FixedExtentScrollController(initialItem: _selectedChapter);
    _verseController =
        FixedExtentScrollController(initialItem: _selectedVerse);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await widget.historyRepo.load();
    if (mounted) setState(() => _history = history);
  }

  int get _interactionStyle => widget.config.interactionStyle;

  void _resetAutoCollapseTimer() {
    if (_interactionStyle != 2) return;
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) widget.onCollapse();
    });
  }

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    _bookController.dispose();
    _chapterController.dispose();
    _verseController.dispose();
    super.dispose();
  }

  void _onBookChanged(int index) {
    widget.haptics.tick();
    setState(() {
      _selectedBook = index;
      _selectedChapter = 0;
      _selectedVerse = 0;
      _chapterPickerKey++;
      _versePickerKey++;
    });
    _chapterController.dispose();
    _chapterController = FixedExtentScrollController(initialItem: 0);
    _verseController.dispose();
    _verseController = FixedExtentScrollController(initialItem: 0);
    widget.onSelectionChanged(_selectedBook, _selectedChapter, _selectedVerse);
    _resetAutoCollapseTimer();
  }

  void _onChapterChanged(int index) {
    widget.haptics.tick();
    setState(() {
      _selectedChapter = index;
      _selectedVerse = 0;
      _versePickerKey++;
    });
    _verseController.dispose();
    _verseController = FixedExtentScrollController(initialItem: 0);
    widget.onSelectionChanged(_selectedBook, _selectedChapter, _selectedVerse);
    _resetAutoCollapseTimer();
  }

  void _onVerseChanged(int index) {
    widget.haptics.tick();
    setState(() {
      _selectedVerse = index;
    });
    widget.onSelectionChanged(_selectedBook, _selectedChapter, _selectedVerse);
    _resetAutoCollapseTimer();
  }

  String get _language => widget.config.language;

  Future<void> _onBookTap(int index) async {
    widget.haptics.selectionClick();
    await LauncherService.launchBook(_currentBook.number, _currentBook.name, language: _language);
  }

  Future<void> _onChapterTap(int index) async {
    widget.haptics.selectionClick();
    await LauncherService.launchChapter(
      _currentBook.number,
      _selectedChapter + 1,
      _currentBook.name,
      language: _language,
    );
  }

  Future<void> _onVerseTap(int index) async {
    widget.haptics.selectionClick();
    _autoCollapseTimer?.cancel();
    final ref = BibleReference(
      book: _currentBook.number,
      chapter: _selectedChapter + 1,
      verse: _selectedVerse + 1,
      bookName: _currentBook.name,
    );
    final success = await LauncherService.launch(ref, language: _language);
    if (!mounted) return;
    if (success) {
      final entry = HistoryEntry(
        reference: ref,
        timestamp: DateTime.now(),
      );
      await widget.historyRepo.add(entry);
      if (!mounted) return;
      await _loadHistory();
    }
    // Style 2: auto-collapse after verse selection
    if (_interactionStyle == 2 && mounted) {
      widget.onCollapse();
    }
  }

  void _toggleHistory() {
    setState(() => _showHistory = !_showHistory);
  }

  void _openConfigPage() {
    NwtVibration.openMainApp();
  }

  Future<void> _onHistoryEntryTap(HistoryEntry entry) async {
    setState(() => _showHistory = false);
    await LauncherService.launch(entry.reference);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main tube bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left handle (left half of compass rose)
              LeftHandle(
                theme: widget.theme,
                width: _handleWidth,
                onTap: widget.onCollapse,
                onSwipeUp: _toggleHistory,
              ),
              // Tube body — transparent; only selection row has background
              Expanded(
                child: _buildPickerBody(),
              ),
              // Right handle — opens config page
              RightHandle(
                theme: widget.theme,
                width: _handleWidth,
                onTap: _openConfigPage,
              ),
            ],
          ),
          // History popup
          if (_showHistory)
            Positioned(
              bottom: _itemExtent * 3.0 + 4,
              left: 0,
              child: HistoryPopup(
                entries: _history,
                theme: widget.theme,
                onEntryTap: _onHistoryEntryTap,
                onClose: () => setState(() => _showHistory = false),
              ),
            ),
        ],
      ),
    );
  }

  /// Wraps a picker with top/bottom fade gradients so non-selected rows
  /// fade out — keeps the overlay subtle.
  Widget _fadedPicker(Widget picker) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.75),
            Colors.white,
            Colors.white,
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.10),
          ],
          stops: const [0.0, 0.12, 0.25, 0.38, 0.62, 0.75, 0.88, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: picker,
    );
  }

  Widget _buildPickerBody() {
    final ie = _itemExtent;
    final fs = widget.config.fontSize;

    return Stack(
      children: [
        // Selection row background — height controlled by config
        Center(
          child: Container(
            height: ie * widget.config.selectionBarHeight,
            decoration: BoxDecoration(
              color: widget.theme.background.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(4),
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: widget.theme.divider.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
            ),
          ),
        ),
        // Pickers on top
        Row(
          children: [
            // Book picker — flex 5
            Expanded(
              flex: 5,
              child: _fadedPicker(
                BookPicker(
                  books: widget.books,
                  controller: _bookController,
                  nameLength: widget.config.nameLength,
                  fontSize: fs,
                  itemExtent: ie,
                  theme: widget.theme,
                  onSelectedItemChanged: _onBookChanged,
                  onTap: _onBookTap,
                ),
              ),
            ),
            Container(
              width: 1,
              height: ie * 0.8,
              color: widget.theme.divider.withValues(alpha: 0.3),
            ),
            // Chapter picker — flex 2
            Expanded(
              flex: 2,
              child: _fadedPicker(
                ChapterPicker(
                  key: ValueKey('ch_$_chapterPickerKey'),
                  chapterCount: _chapterCount,
                  controller: _chapterController,
                  fontSize: fs,
                  itemExtent: ie,
                  theme: widget.theme,
                  onSelectedItemChanged: _onChapterChanged,
                  onTap: _onChapterTap,
                ),
              ),
            ),
            // Colon separator
            Text(
              ':',
              style: TextStyle(
                color: widget.theme.textSecondary.withValues(alpha: 0.7),
                fontSize: fs - 1,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Verse picker — flex 2
            Expanded(
              flex: 2,
              child: _fadedPicker(
                VersePicker(
                  key: ValueKey('vs_$_versePickerKey'),
                  verseCount: _verseCount,
                  controller: _verseController,
                  fontSize: fs,
                  itemExtent: ie,
                  theme: widget.theme,
                  onSelectedItemChanged: _onVerseChanged,
                  onTap: _onVerseTap,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
