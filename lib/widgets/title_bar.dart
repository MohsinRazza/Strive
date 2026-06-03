import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../design_system.dart';

/// Custom frameless title bar with drag-to-move, theme toggle,
/// mini-mode toggle, and native window controls.
class TitleBar extends StatelessWidget {
  final ThemePreference themePreference;
  final AccentTheme accentTheme;
  final VoidCallback onThemeToggle;
  final ValueChanged<AccentTheme> onAccentChange;
  final AppColors colors;
  final VoidCallback? onMiniMode;

  const TitleBar({
    super.key,
    required this.themePreference,
    required this.accentTheme,
    required this.onThemeToggle,
    required this.onAccentChange,
    required this.colors,
    this.onMiniMode,
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
          // Draggable logo area
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) async {
                if (!kIsWeb &&
                    (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
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

          // Accent Theme Dropdown
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: colors.primary.withOpacity(0.05),
              hoverColor: colors.primary.withOpacity(0.05),
            ),
            child: PopupMenuButton<AccentTheme>(
              initialValue: accentTheme,
              tooltip: 'Theme & Accent',
              position: PopupMenuPosition.under,
              offset: const Offset(0, 8),
              icon: Icon(Icons.palette_outlined, size: 16, color: colors.foreground),
              onSelected: onAccentChange,
              color: colors.card,
              elevation: 6,
              shadowColor: Colors.black.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.border.withOpacity(0.5)),
              ),
              itemBuilder: (context) {
                return AccentTheme.values.map((theme) {
                  final isSelected = theme == accentTheme;
                  return PopupMenuItem(
                    value: theme,
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: theme.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.border, width: 0.5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            theme.label,
                            style: AppDesign.getBodyMutedStyle(colors).copyWith(
                              color: isSelected ? colors.foreground : colors.muted,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_rounded, size: 16, color: colors.foreground)
                        else
                          const SizedBox(width: 16),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          ),

          // Theme Toggle (Light / Dark / System)
          IconButton(
            icon: Icon(
              themePreference == ThemePreference.light
                  ? Icons.light_mode_outlined
                  : (themePreference == ThemePreference.dark
                      ? Icons.dark_mode_outlined
                      : Icons.brightness_auto_outlined),
              size: 16,
              color: colors.foreground,
            ),
            tooltip: 'Toggle Theme',
            onPressed: onThemeToggle,
            splashRadius: 18,
          ),

          // Mini Mode Toggle
          if (onMiniMode != null)
            IconButton(
              icon: Icon(Icons.picture_in_picture_alt_rounded, size: 15, color: colors.foreground),
              tooltip: 'Mini Timer',
              onPressed: onMiniMode,
              splashRadius: 18,
            ),

          // Native Window Controls (desktop only)
          if (!kIsWeb &&
              (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) ...[
            Container(
              width: 1,
              height: 20,
              color: colors.border,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            IconButton(
              icon: Icon(Icons.remove, size: 14, color: colors.foreground),
              onPressed: () async => windowManager.minimize(),
              splashRadius: 18,
              tooltip: 'Minimize',
            ),
            IconButton(
              icon: Icon(Icons.crop_square, size: 12, color: colors.foreground),
              onPressed: () async {
                final isMax = await windowManager.isMaximized();
                isMax ? await windowManager.unmaximize() : await windowManager.maximize();
              },
              splashRadius: 18,
              tooltip: 'Maximize',
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
              onPressed: () async => windowManager.close(),
              splashRadius: 18,
              tooltip: 'Close',
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
