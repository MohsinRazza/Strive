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
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final isDark = await SessionStorage.loadDarkModePreference();
    setState(() => _isDarkMode = isDark);
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      SessionStorage.saveDarkModePreference(_isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strive',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.focusAccent,
          brightness: Brightness.light,
          background: AppColors.light.background,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.focusAccent,
          brightness: Brightness.dark,
          background: AppColors.dark.background,
        ),
      ),
      home: StriveHomeScreen(
        isDarkMode: _isDarkMode,
        onThemeToggle: _toggleTheme,
      ),
    );
  }
}
