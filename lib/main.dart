import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'design_system.dart';
import 'session_storage.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(950, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(false);
      await windowManager.setTitle('Strive');
      await windowManager.setIcon('assets/images/logo_s.png');
    });
  }

  runApp(const StriveApp());
}

class StriveApp extends StatefulWidget {
  const StriveApp({super.key});

  @override
  State<StriveApp> createState() => _StriveAppState();
}

class _StriveAppState extends State<StriveApp> {
  ThemePreference _themePreference = ThemePreference.system;
  AccentTheme _accentTheme = AccentTheme.purple;
  bool _showLaps = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SessionStorage.loadSettings();
    setState(() {
      final themeStr = settings['themeMode'] as String? ?? 'system';
      _themePreference = ThemePreference.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => ThemePreference.system,
      );

      final accentStr = settings['accentTheme'] as String? ?? 'purple';
      _accentTheme = AccentTheme.values.firstWhere(
        (e) => e.name == accentStr,
        orElse: () => AccentTheme.purple,
      );

      _showLaps = settings['showLaps'] as bool? ?? true;
    });
  }

  void _cycleTheme() {
    setState(() {
      if (_themePreference == ThemePreference.light) {
        _themePreference = ThemePreference.dark;
      } else if (_themePreference == ThemePreference.dark) {
        _themePreference = ThemePreference.system;
      } else {
        _themePreference = ThemePreference.light;
      }
      SessionStorage.saveSettings({'themeMode': _themePreference.name});
    });
  }

  void _setAccent(AccentTheme theme) {
    setState(() {
      _accentTheme = theme;
      SessionStorage.saveSettings({'accentTheme': theme.name});
    });
  }

  void _toggleLaps() {
    setState(() {
      _showLaps = !_showLaps;
      SessionStorage.saveSettings({'showLaps': _showLaps});
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeMode themeMode;
    switch (_themePreference) {
      case ThemePreference.light:
        themeMode = ThemeMode.light;
        break;
      case ThemePreference.dark:
        themeMode = ThemeMode.dark;
        break;
      case ThemePreference.system:
        themeMode = ThemeMode.system;
        break;
    }

    final lightColors = AppColors.get(isDark: false, accent: _accentTheme);
    final darkColors = AppColors.get(isDark: true, accent: _accentTheme);

    return MaterialApp(
      title: 'Strive',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: lightColors.focusAccent,
          brightness: Brightness.light,
          background: lightColors.background,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkColors.focusAccent,
          brightness: Brightness.dark,
          background: darkColors.background,
        ),
      ),
      home: StriveHomeScreen(
        themePreference: _themePreference,
        accentTheme: _accentTheme,
        showLaps: _showLaps,
        onThemeToggle: _cycleTheme,
        onAccentChange: _setAccent,
        onLapsToggle: _toggleLaps,
      ),
    );
  }
}
