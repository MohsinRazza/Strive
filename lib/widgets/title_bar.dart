import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../design_system.dart';

class TitleBar extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;
  final AppColors colors;

  const TitleBar({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDesign.transitionDuration,
      curve: AppDesign.transitionCurve,
      height: 44,
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(bottom: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) async {
                if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
                  await windowManager.startDragging();
                }
              },
              child: Container(
                alignment: Alignment.centerLeft,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('assets/images/logo_s.png', height: 22, width: 22),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 16,
              color: colors.foreground,
            ),
            tooltip: 'Toggle Theme',
            onPressed: onThemeToggle,
            splashRadius: 18,
          ),
          if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) ...[
            Container(width: 1, height: 20, color: colors.border, margin: const EdgeInsets.symmetric(horizontal: 4)),
            IconButton(icon: Icon(Icons.remove, size: 14, color: colors.foreground), onPressed: () async => windowManager.minimize(), splashRadius: 18, tooltip: 'Minimize'),
            IconButton(
              icon: Icon(Icons.crop_square, size: 12, color: colors.foreground),
              onPressed: () async {
                final isMax = await windowManager.isMaximized();
                isMax ? await windowManager.unmaximize() : await windowManager.maximize();
              },
              splashRadius: 18,
              tooltip: 'Maximize',
            ),
            IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.redAccent), onPressed: () async => windowManager.close(), splashRadius: 18, tooltip: 'Close'),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
