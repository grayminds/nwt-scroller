import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bible_data.dart';
import '../data/bible_repository.dart';
import '../data/history_repository.dart';
import '../services/overlay_service.dart';
import '../services/screen_service.dart';
import '../services/haptic_service.dart';
import '../services/config_service.dart';
import '../theme/scroll_theme.dart';
import '../theme/parchment_theme.dart';
import '../theme/silver_theme.dart';
import 'collapsed_scroll.dart';
import 'expanded_scroll.dart';

class ScrollOverlay extends StatefulWidget {
  const ScrollOverlay({super.key});

  @override
  State<ScrollOverlay> createState() => _ScrollOverlayState();
}

class _ScrollOverlayState extends State<ScrollOverlay>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _loading = true;
  List<BibleBook> _books = [];

  final _bibleRepo = BibleRepository();
  final _historyRepo = HistoryRepository();
  final _config = ConfigService();
  late HapticService _haptics;
  late ScrollTheme _theme;

  late AnimationController _animController;
  late Animation<double> _expandAnimation;
  StreamSubscription? _dataSub;

  /// Expanded position — used to compute left-knob collapse target
  double _expandedX = 0;
  double _expandedY = 0;

  /// Unified compass size derived from config
  int get _collapsedSize =>
      OverlayService.compassSize(_config.fontSize, _config.overlayScale);

  /// Expanded bar height — taller than compass to show 5 picker rows
  int get _expandedHeight => (_collapsedSize * 5 / 3).round();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _init();
  }

  Future<void> _init() async {
    try {
      await _config.load();
      _haptics = HapticService(
        enabled: _config.hapticEnabled,
        intensity: _config.hapticIntensity,
      );
      _theme = _resolveTheme(_config.theme);
      _books = await _bibleRepo.loadBooks();
    } catch (e) {
      _haptics = HapticService();
      _theme = ParchmentTheme();
      _books = [];
    }

    _dataSub = OverlayService.overlayListener.listen(_onDataReceived);

    // Resize to the config-derived size (showOverlay already used this size,
    // but this ensures consistency if config changed between calls)
    try {
      await OverlayService.resizeToCollapsed(_collapsedSize);
    } catch (_) {}

    // Position is set by main app in _startOverlay() — not here,
    // because ScreenService returns wrong values in the overlay engine.

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _onDataReceived(dynamic data) {
    if (data == null) return;
    if (data is Map) {
      final type = data['type'];
      if (type == 'config') {
        _config.applyFromMap(Map<String, dynamic>.from(data));
        _onConfigChanged();
      }
    }
  }

  ScrollTheme _resolveTheme(String name) {
    switch (name) {
      case 'silver':
        return SilverTheme();
      default:
        return ParchmentTheme();
    }
  }

  int _computeExpandedWidth(double screenWidth) {
    final fs = _config.fontSize;
    final scale = _config.overlayScale;
    final hw = OverlayService.handleWidth(_collapsedSize);
    final handleTotal = hw * 2;
    final separatorWidth = 6;

    final maxBookChars = switch (_config.nameLength) {
      NameLength.short => 3,
      NameLength.medium => 7,
      NameLength.long => 12,
    };
    final bookWidth = (maxBookChars * fs * 0.38).round();
    final numWidth = (3 * fs * 0.38).round();

    final contentWidth = bookWidth + numWidth * 2 + separatorWidth;
    // Scale only the content; handles already derive from scaled _collapsedSize
    final totalWidth = (contentWidth * scale + handleTotal).round();

    final maxWidth = (screenWidth * 0.9).round();
    return totalWidth.clamp(120, maxWidth);
  }

  Future<void> _expand() async {
    try {
      final screen = ScreenService.getScreenSize();
      final screenWidth = screen.width;
      final screenHeight = screen.height;

      final pos = await OverlayService.getPosition();
      if (!mounted) return;

      final cs = _collapsedSize;
      final expandedWidth = _computeExpandedWidth(screenWidth);
      final expandedHeight = _expandedHeight;

      final collapsedCenterX = pos.x + cs / 2;
      final collapsedCenterY = pos.y + cs / 2;
      final third = screenWidth / 3;

      double newX;
      if (collapsedCenterX < third) {
        newX = pos.x;
      } else if (collapsedCenterX < third * 2) {
        newX = collapsedCenterX - expandedWidth / 2;
      } else {
        newX = pos.x + cs - expandedWidth;
      }

      newX = newX.clamp(
          0.0, (screenWidth - expandedWidth).clamp(0.0, screenWidth));
      final newY = (collapsedCenterY - expandedHeight / 2).clamp(
          0.0,
          (screenHeight - expandedHeight).clamp(0.0, screenHeight));

      await OverlayService.resizeToExpanded(expandedWidth, expandedHeight);
      await OverlayService.moveOverlay(newX, newY);
      _expandedX = newX;
      _expandedY = newY;

      if (!mounted) return;
      _animController.forward();
      setState(() => _expanded = true);
    } catch (_) {
      try {
        await OverlayService.resizeToExpanded(280, _expandedHeight);
        await OverlayService.moveOverlay(20, 200);
        _expandedX = 20;
        _expandedY = 200;
        if (!mounted) return;
        _animController.forward();
        setState(() => _expanded = true);
      } catch (_) {}
    }
  }

  Future<void> _collapse() async {
    // Collapse to the left knob position: the collapsed compass appears
    // where the left handle was in the expanded bar.
    try {
      final pos = await OverlayService.getPosition();
      final cs = _collapsedSize;
      final eh = _expandedHeight;
      // Left knob center aligns with collapsed compass center
      final collapseX = pos.x;
      final collapseY = pos.y + eh / 2 - cs / 2;

      await _animController.reverse();
      if (!mounted) return;
      await OverlayService.moveOverlay(collapseX, collapseY);
      await OverlayService.resizeToCollapsed(cs);
      if (!mounted) return;
      setState(() => _expanded = false);
    } catch (_) {
      try {
        await _animController.reverse();
      } catch (_) {}
      if (!mounted) return;
      try {
        await OverlayService.moveOverlay(_expandedX, _expandedY);
        await OverlayService.resizeToCollapsed(_collapsedSize);
      } catch (_) {}
      setState(() => _expanded = false);
    }
  }

  void _onConfigChanged() {
    if (!mounted) return;
    setState(() {
      _theme = _resolveTheme(_config.theme);
      _haptics.enabled = _config.hapticEnabled;
      _haptics.intensity = _config.hapticIntensity;
    });
    if (_expanded) {
      _resizeExpanded();
    } else {
      // Resize the collapsed window to match the new config-derived size
      _resizeCollapsed();
    }
  }

  Future<void> _resizeExpanded() async {
    try {
      final screen = ScreenService.getScreenSize();
      final width = _computeExpandedWidth(screen.width);
      final height = _expandedHeight;
      await OverlayService.resizeToExpanded(width, height);
    } catch (_) {}
  }

  Future<void> _resizeCollapsed() async {
    try {
      await OverlayService.resizeToCollapsed(_collapsedSize);
    } catch (_) {}
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.expand();
    }

    if (!_expanded) {
      return CollapsedScroll(
        theme: _theme,
        onTap: _expand,
      );
    }

    return FadeTransition(
      opacity: _expandAnimation,
      child: ExpandedScroll(
        books: _books,
        theme: _theme,
        config: _config,
        haptics: _haptics,
        historyRepo: _historyRepo,
        onCollapse: _collapse,
        onConfigChanged: _onConfigChanged,
      ),
    );
  }
}
