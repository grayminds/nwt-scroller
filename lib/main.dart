import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/overlay_service.dart';
import 'services/screen_service.dart';
import 'services/config_service.dart';
import 'services/haptic_service.dart';
import 'widgets/scroll_overlay.dart';

void main() {
  runApp(const NwtScrollerApp());
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
    return MaterialApp(
      title: 'NWT Scroller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B4513),
        ),
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
    with WidgetsBindingObserver {
  bool _permissionGranted = false;
  bool _overlayActive = false;
  final _config = ConfigService();
  bool _configLoaded = false;
  StreamSubscription? _overlayDataSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForOverlayData();
    _initAndAutoStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayDataSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      _checkOverlayStatus();
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
      // Currently no messages expected from overlay to main app.
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
    await _config.save();
    final size = OverlayService.compassSize(_config.fontSize, _config.overlayScale);
    await OverlayService.showOverlay(size);
    // Position from main app (overlay engine can't reliably detect screen size)
    try {
      if (_config.screenWidth > 200 && _config.screenHeight > 200) {
        await OverlayService.setDefaultPosition(
            _config.screenWidth, _config.screenHeight, size);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _overlayActive = true);
    // Push config after a brief delay to let overlay initialize
    Future.delayed(const Duration(milliseconds: 500), _pushConfigToOverlay);
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

  /// Update config, save, and push to overlay immediately.
  void _updateConfig(void Function() mutate) {
    setState(mutate);
    _config.save();
    _pushConfigToOverlay();
  }

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xFF5C3A1E);
    const brownLight = Color(0xFF8B6F47);

    return Scaffold(
      backgroundColor: const Color(0xFFF5E6C8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: SvgPicture.asset(
                      'assets/svg/compass_rose.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NWT Scroller',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: brown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quick Bible navigation overlay',
                    style: TextStyle(fontSize: 16, color: brownLight),
                  ),
                  const SizedBox(height: 32),
                  if (!_permissionGranted) ...[
                    Text(
                      'Overlay permission is required to display the scroll navigator above other apps.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: brown),
                    ),
                    const SizedBox(height: 16),
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
                        backgroundColor: const Color(0xFF8B4513),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                    ),
                  ] else ...[
                    if (_overlayActive) ...[
                      Icon(Icons.check_circle,
                          color: Colors.green.shade700, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Overlay is running',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    ElevatedButton.icon(
                      onPressed: _closeApp,
                      icon: const Icon(Icons.close),
                      label: const Text('Close App'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B6F47),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The overlay will keep running after closing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: brownLight),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (_configLoaded) _buildConfigSection(brown, brownLight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigSection(Color brown, Color brownLight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDD9B5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBB896)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: brown,
            ),
          ),
          const SizedBox(height: 16),
          _buildDropdownRow(
            label: 'Language',
            value: 'English',
            items: const ['English'],
            enabled: false,
            brown: brown,
            brownLight: brownLight,
          ),
          const SizedBox(height: 12),
          _buildDropdownRow(
            label: 'Bible',
            value: 'NWT',
            items: const ['NWT', 'Study Bible'],
            enabled: false,
            brown: brown,
            brownLight: brownLight,
          ),
          const SizedBox(height: 16),
          _buildNameLengthRow(brown),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Overlay size',
            value: _config.overlayScale,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            displayValue: '${(_config.overlayScale * 100).round()}%',
            onChanged: (v) {
              _updateConfig(() => _config.overlayScale = v);
            },
            brown: brown,
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
              _updateConfig(() => _config.fontSize = v);
            },
            brown: brown,
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Width scale',
            value: _config.widthScale,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            displayValue: '${(_config.widthScale * 100).round()}%',
            onChanged: (v) {
              _updateConfig(() => _config.widthScale = v);
            },
            brown: brown,
          ),
          const SizedBox(height: 16),
          _buildSwitchRow(
            label: 'Haptic feedback',
            value: _config.hapticEnabled,
            onChanged: (v) {
              _updateConfig(() => _config.hapticEnabled = v);
            },
            brown: brown,
          ),
          if (_config.hapticEnabled) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  Text('Intensity',
                      style: TextStyle(color: brown, fontSize: 13)),
                  const Spacer(),
                  ...HapticIntensity.values.map((h) {
                    final sel = _config.hapticIntensity == h;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: GestureDetector(
                        onTap: () {
                          _updateConfig(
                              () => _config.hapticIntensity = h);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF8B4513)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: sel
                                  ? const Color(0xFF8B4513)
                                  : const Color(0xFFCBB896),
                            ),
                          ),
                          child: Text(
                            h.name[0].toUpperCase() + h.name.substring(1),
                            style: TextStyle(
                              color: sel ? Colors.white : brown,
                              fontSize: 12,
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Theme', style: TextStyle(color: brown, fontSize: 14)),
              const Spacer(),
              _themeChip('parchment', 'Parchment', brown),
              const SizedBox(width: 8),
              _themeChip('silver', 'Silver', brown),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required bool enabled,
    required Color brown,
    required Color brownLight,
  }) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                color: enabled ? brown : brownLight, fontSize: 14)),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBB896)),
          ),
          child: Text(value,
              style: TextStyle(
                  color: enabled ? brown : brownLight, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color brown,
  }) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: brown, fontSize: 14)),
        const Spacer(),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF8B4513),
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
    required Color brown,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child:
              Text(label, style: TextStyle(color: brown, fontSize: 14)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: const Color(0xFF8B4513),
            inactiveColor: const Color(0xFFCBB896),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(displayValue,
              style: TextStyle(color: brown, fontSize: 13),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildNameLengthRow(Color brown) {
    const labels = {'Short': NameLength.short, 'Medium': NameLength.medium, 'Long': NameLength.long};
    return Row(
      children: [
        Text('Book names', style: TextStyle(color: brown, fontSize: 14)),
        const Spacer(),
        ...labels.entries.map((e) {
          final sel = _config.nameLength == e.value;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () {
                _updateConfig(() => _config.nameLength = e.value);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF8B4513) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: sel ? const Color(0xFF8B4513) : const Color(0xFFCBB896),
                  ),
                ),
                child: Text(
                  e.key,
                  style: TextStyle(
                    color: sel ? Colors.white : brown,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _themeChip(String name, String label, Color brown) {
    final sel = _config.theme == name;
    return GestureDetector(
      onTap: () {
        _updateConfig(() => _config.theme = name);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:
              sel ? const Color(0xFF8B4513) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel
                ? const Color(0xFF8B4513)
                : const Color(0xFFCBB896),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : brown,
            fontSize: 13,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
