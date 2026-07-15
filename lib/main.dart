import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/overlay_service.dart';
import 'services/screen_service.dart';
import 'services/config_service.dart';
import 'services/haptic_service.dart';
import 'data/history_repository.dart';
import 'models/history_entry.dart';
import 'widgets/scroll_overlay.dart';

void main() {
  runApp(const NwtScrollerApp());
}

/// Guards against a re-entrant overlay start.  Three code paths can enter the
/// start flow in quick succession:  the initState auto-start, the
/// lifecycle-resumed re-check, and the Grant Permission button.  Without a
/// guard they fire two `startService` calls, which the native side turns into
/// a flashing overlay that vanishes.  The first caller wins; a second caller
/// gets false and must return early.  Callers clear the guard in a `finally`
/// so a failed start does not wedge the flow shut.
class OverlayStartGuard {
  bool _running = false;

  bool get isRunning => _running;

  /// Returns true if the caller may begin a start.  A second concurrent caller
  /// receives false and must return early without starting the overlay.
  bool begin() {
    if (_running) return false;
    _running = true;
    return true;
  }

  /// Clears the guard so a later, separate start attempt can proceed.
  void end() {
    _running = false;
  }
}

// Overlay entry point
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
      ),
      home: const Material(
        type: MaterialType.transparency,
        child: ScrollOverlay(),
      ),
    ),
  );
}

class NwtScrollerApp extends StatelessWidget {
  const NwtScrollerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Seed the Material 3 scheme from the parchment palette, then pin the
    // handful of roles the config UI actually reads.  Every widget consumes
    // Theme.of(context) instead of repeating raw hex literals.
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B4513),
    ).copyWith(
      primary: const Color(0xFF8B4513),
      onPrimary: Colors.white,
      surface: const Color(0xFFF5E6C8),
      onSurface: const Color(0xFF5C3A1E),
      onSurfaceVariant: const Color(0xFF8B6F47),
      surfaceContainerHighest: const Color(0xFFEDD9B5),
      outlineVariant: const Color(0xFFCBB896),
    );

    return MaterialApp(
      title: 'NWT Scroller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        useMaterial3: true,
      ),
      home: const PermissionPage(),
    );
  }
}

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _permissionGranted = false;
  bool _overlayActive = false;
  final _config = ConfigService();
  final _historyRepo = HistoryRepository();
  bool _configLoaded = false;
  StreamSubscription? _overlayDataSub;
  List<HistoryEntry> _history = [];
  late TabController _tabController;

  /// Serializes the three entrants into the overlay start flow.
  final _startGuard = OverlayStartGuard();

  /// Fallback timer that pushes config if the overlay's ready message never
  /// arrives.  Cancelled when the ready message lands first.
  Timer? _configPushTimer;

  /// Trailing debounce for slider persistence, so a drag writes
  /// SharedPreferences once instead of on every tick.
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addObserver(this);
    _listenForOverlayData();
    _initAndAutoStart();
  }

  void _onTabChanged() {
    if (_tabController.index == 1) _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyRepo.load();
    if (mounted) setState(() => _history = history);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _overlayDataSub?.cancel();
    _configPushTimer?.cancel();
    // Flush a pending debounced save so a last-moment slider change is not lost
    // when the config page closes.
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _config.save();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndStart();
    }
  }

  Future<void> _checkPermissionAndStart() async {
    final granted = await OverlayService.checkPermission();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
    if (_permissionGranted) {
      await _checkOverlayStatus();
      if (!_overlayActive) {
        await _startOverlay();
      } else {
        _pushConfigToOverlay();
      }
    }
  }

  Future<void> _initAndAutoStart() async {
    await _loadConfig();
    await _checkPermission();
    if (_permissionGranted) {
      await _checkOverlayStatus();
      if (!_overlayActive) {
        await _startOverlay();
      } else {
        // Already running — push latest config
        _pushConfigToOverlay();
      }
    }
  }

  void _listenForOverlayData() {
    _overlayDataSub =
        FlutterOverlayWindow.overlayListener.listen((data) {
      // The overlay announces it finished loading with {type: 'ready'}.  Push
      // config immediately and cancel the fallback timer.
      if (data is Map && data['type'] == 'ready') {
        _configPushTimer?.cancel();
        _pushConfigToOverlay();
      }
    });
  }

  Future<void> _loadConfig() async {
    await _config.load();
    // Populate screen dimensions from main app context
    try {
      final screen = ScreenService.getScreenSize();
      if (screen.width > 200 && screen.height > 200) {
        _config.screenWidth = screen.width;
        _config.screenHeight = screen.height;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _configLoaded = true);
  }

  Future<void> _checkPermission() async {
    final granted = await OverlayService.requestPermission();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
  }

  Future<void> _checkOverlayStatus() async {
    final active = await OverlayService.isActive();
    if (!mounted) return;
    setState(() => _overlayActive = active);
  }

  Future<void> _startOverlay() async {
    // Only the first entrant proceeds; a second returns early.  The guard is
    // cleared in the finally so a failed start does not wedge the flow.
    if (!_startGuard.begin()) return;
    try {
      await _config.save();
      final compass = OverlayService.compassSize(_config.overlayScale);
      final size = OverlayService.collapsedDisplaySize(compass);

      // Compute the initial collapsed position in logical pixels and hand it to
      // showOverlay so the window opens already placed.  The old post-hoc move
      // raced window creation and could no-op against a not-yet-live service.
      // This mirrors OverlayService.setDefaultPosition's formula.
      OverlayPosition? startPosition;
      if (_config.screenWidth > 200 && _config.screenHeight > 200) {
        final startX = (_config.screenWidth / 3) - (size / 2);
        final startY = (_config.screenHeight * 2 / 3) - (size / 2);
        startPosition = OverlayPosition(startX, startY);
      }

      // Arm the config push before showing the overlay so the ready message is
      // never missed.  The listener pushes config on {type: 'ready'}; this
      // timer is the generous fallback if that message never arrives.
      _configPushTimer?.cancel();
      _configPushTimer =
          Timer(const Duration(seconds: 3), _pushConfigToOverlay);

      // startPosition is not exposed through OverlayService.showOverlay, so
      // call the plugin directly to place the window at creation time.  All
      // other parameters match OverlayService.showOverlay.
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        height: size,
        width: size,
        alignment: OverlayAlignment.topLeft,
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        startPosition: startPosition,
      );

      if (!mounted) return;
      setState(() => _overlayActive = true);
    } finally {
      _startGuard.end();
    }
  }

  Future<void> _closeApp() async {
    try {
      await OverlayService.closeOverlay();
    } catch (_) {}
    SystemNavigator.pop();
  }

  /// Push current config to overlay via data sharing.
  Future<void> _pushConfigToOverlay() async {
    if (!_overlayActive) return;
    try {
      await OverlayService.shareData(_config.toMap());
    } catch (_) {}
  }

  /// Update config for a discrete control, save immediately, and push to the
  /// overlay.  Suitable for switches, chips, and dropdowns.
  void _updateConfig(void Function() mutate) {
    setState(mutate);
    _config.save();
    _pushConfigToOverlay();
  }

  /// Update config for a continuous control (a slider).  Applies and pushes
  /// live, but debounces the SharedPreferences write so a drag persists once
  /// on settle instead of on every tick.
  void _updateConfigDebounced(void Function() mutate) {
    setState(mutate);
    _pushConfigToOverlay();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), _config.save);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Compact header row
                  Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: SvgPicture.asset(
                          'assets/svg/compass_rose.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NWT Scroller',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            Text(
                              'Quick Bible navigation overlay',
                              style: TextStyle(
                                  fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (_permissionGranted && _overlayActive)
                        Icon(Icons.check_circle,
                            color: Colors.green.shade700, size: 24),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_permissionGranted) ...[
                    Text(
                      'Overlay permission is required to display the scroll navigator above other apps.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _checkPermission();
                        if (_permissionGranted && !_overlayActive) {
                          _startOverlay();
                        }
                      },
                      icon: const Icon(Icons.security),
                      label: const Text('Grant Permission'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _closeApp,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Close App'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.onSurfaceVariant,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Overlay keeps running',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_configLoaded) ...[
                    TabBar(
                      controller: _tabController,
                      labelColor: cs.onSurface,
                      unselectedLabelColor: cs.onSurfaceVariant,
                      indicatorColor: cs.primary,
                      tabs: const [
                        Tab(text: 'Configuration'),
                        Tab(text: 'History'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          SingleChildScrollView(
                            child: _buildConfigSection(),
                          ),
                          _buildHistoryTab(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Language'),
          const SizedBox(height: 10),
          _buildLanguageRow(),
          const SizedBox(height: 12),
          _buildDropdownRow(
            label: 'Bible',
            value: 'NWT',
            items: const ['NWT', 'Study Bible'],
            enabled: false,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Appearance'),
          const SizedBox(height: 10),
          _buildThemeRow(),
          const SizedBox(height: 16),
          _buildNameLengthRow(),
          const SizedBox(height: 16),
          _buildSliderRow(
            label: 'Overlay size',
            value: _config.overlayScale,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            displayValue: '${(_config.overlayScale * 100).round()}%',
            onChanged: (v) {
              _updateConfigDebounced(() => _config.overlayScale = v);
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Font size',
            value: _config.fontSize,
            min: 10,
            max: 32,
            divisions: 22,
            displayValue: '${_config.fontSize.round()}',
            onChanged: (v) {
              _updateConfigDebounced(() => _config.fontSize = v);
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Bar width',
            value: _config.widthScale,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            displayValue: '${(_config.widthScale * 100).round()}%',
            onChanged: (v) {
              _updateConfigDebounced(() => _config.widthScale = v);
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Wheel height',
            value: _config.heightScale,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            displayValue: '${(_config.heightScale * 100).round()}%',
            onChanged: (v) {
              _updateConfigDebounced(() => _config.heightScale = v);
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Selection row height',
            value: _config.selectionBarHeight,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            displayValue: '${(_config.selectionBarHeight * 100).round()}%',
            onChanged: (v) {
              _updateConfigDebounced(() => _config.selectionBarHeight = v);
            },
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Opacity',
            // Clamp for display so a stale sub-floor value cannot trip the
            // Slider min assertion during the transition to the 0.4 floor.
            value: _config.overlayOpacity.clamp(0.4, 1.0),
            min: 0.4,
            max: 1.0,
            divisions: 6,
            displayValue: '${(_config.overlayOpacity * 100).round()}%',
            onChanged: (v) {
              _updateConfigDebounced(() => _config.overlayOpacity = v);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Behavior'),
          const SizedBox(height: 10),
          _buildInteractionStyleRow(),
          const SizedBox(height: 16),
          _buildSwitchRow(
            label: 'Haptic feedback',
            value: _config.hapticEnabled,
            onChanged: (v) {
              _updateConfig(() => _config.hapticEnabled = v);
            },
          ),
          if (_config.hapticEnabled) ...[
            const SizedBox(height: 8),
            _buildHapticIntensityRow(),
          ],
        ],
      ),
    );
  }

  /// A small caps subheader that groups related settings for scannability.
  Widget _buildSectionHeader(String title) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  /// A settings option row for a small, mutually-exclusive set of choices.
  /// The label sits above a full-width Material 3 SegmentedButton, so the
  /// control never wraps or overflows regardless of device width or text
  /// scale, and it carries proper selected semantics for TalkBack.
  Widget _buildSegmentedRow<T>({
    required String label,
    required List<({T value, String text})> options,
    required T selected,
    required ValueChanged<T> onSelected,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: cs.onSurface, fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            segments: options
                .map((o) =>
                    ButtonSegment<T>(value: o.value, label: Text(o.text)))
                .toList(),
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onSelected(s.first),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              // Pin the selected state to the parchment brown instead of the
              // auto-generated M3 secondaryContainer, which reads pink and off
              // brand.  Matches the Close App button and the tab indicator.
              foregroundColor: cs.onSurface,
              selectedForegroundColor: cs.onPrimary,
              selectedBackgroundColor: cs.primary,
              side: BorderSide(color: cs.outlineVariant),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeRow() {
    return _buildSegmentedRow<ScrollThemeId>(
      label: 'Theme',
      options: const [
        (value: ScrollThemeId.parchment, text: 'Parchment'),
        (value: ScrollThemeId.silver, text: 'Silver'),
        (value: ScrollThemeId.blue, text: 'Blue'),
      ],
      selected: _config.theme,
      onSelected: (v) => _updateConfig(() => _config.theme = v),
    );
  }

  Widget _buildHapticIntensityRow() {
    return _buildSegmentedRow<HapticIntensity>(
      label: 'Intensity',
      options: HapticIntensity.values
          .map((h) => (
                value: h,
                text: h.name[0].toUpperCase() + h.name.substring(1),
              ))
          .toList(),
      selected: _config.hapticIntensity,
      onSelected: (v) => _updateConfig(() => _config.hapticIntensity = v),
    );
  }

  Widget _buildInteractionStyleRow() {
    final cs = Theme.of(context).colorScheme;
    // Display names and descriptions.  Values are the InteractionStyle enum,
    // serialized by name in ConfigService.
    const styles = [
      (
        value: InteractionStyle.fullWheel,
        name: 'Full wheel',
        description: 'Five visible rows around the selection.'
      ),
      (
        value: InteractionStyle.minimalFade,
        name: 'Minimal fade',
        description: 'Taller wheel with more visible rows.'
      ),
    ];
    final selected = styles.firstWhere(
      (s) => s.value == _config.interactionStyle,
      orElse: () => styles.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSegmentedRow<InteractionStyle>(
          label: 'Interaction',
          options:
              styles.map((s) => (value: s.value, text: s.name)).toList(),
          selected: _config.interactionStyle,
          onSelected: (v) =>
              _updateConfig(() => _config.interactionStyle = v),
        ),
        const SizedBox(height: 4),
        Text(
          selected.description,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required bool enabled,
  }) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = enabled ? cs.onSurface : cs.onSurfaceVariant;
    return Row(
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(value,
              style: TextStyle(color: labelColor, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(label, style: TextStyle(color: cs.onSurface, fontSize: 14)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: cs.primary,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 104,
          child:
              Text(label, style: TextStyle(color: cs.onSurface, fontSize: 14)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: cs.primary,
            inactiveColor: cs.outlineVariant,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(displayValue,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildLanguageRow() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text('Language', style: TextStyle(color: cs.onSurface, fontSize: 14)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: DropdownButton<String>(
            value: _config.language,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: TextStyle(color: cs.onSurface, fontSize: 13),
            dropdownColor: cs.surface,
            items: ConfigService.supportedLanguages.map((lang) {
              return DropdownMenuItem(value: lang, child: Text(lang));
            }).toList(),
            onChanged: (v) {
              if (v != null) _updateConfig(() => _config.language = v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNameLengthRow() {
    return _buildSegmentedRow<NameLength>(
      label: 'Book names',
      options: const [
        (value: NameLength.short, text: 'Short'),
        (value: NameLength.medium, text: 'Medium'),
        (value: NameLength.long, text: 'Long'),
      ],
      selected: _config.nameLength,
      onSelected: (v) => _updateConfig(() => _config.nameLength = v),
    );
  }

  Widget _buildHistoryTab() {
    final cs = Theme.of(context).colorScheme;
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No history yet.\nSelections made in the overlay will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final entry = _history[index];
        final time = _formatTimestamp(entry.timestamp);
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: ListTile(
            dense: true,
            leading: Icon(Icons.history, color: cs.onSurfaceVariant, size: 20),
            title: Text(
              entry.displayLabel,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
            ),
            subtitle: Text(
              time,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline,
                  color: cs.onSurfaceVariant, size: 20),
              onPressed: () async {
                await _historyRepo.removeAt(index);
                await _loadHistory();
              },
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
