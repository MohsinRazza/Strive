import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import '../design_system.dart';
import '../session_model.dart';
import '../session_storage.dart';
import '../dialogs/crash_recovery_dialog.dart';
import '../dialogs/export_dialog.dart';
import '../dialogs/import_dialog.dart';
import '../widgets/title_bar.dart';
import '../widgets/timer_panel.dart';
import '../widgets/sidebar_panel.dart';

// Full window size constants
const _kFullSize = Size(1200, 800);
const _kMiniSize = Size(300, 68);

class StriveHomeScreen extends StatefulWidget {
  final ThemePreference themePreference;
  final AccentTheme accentTheme;
  final bool showLaps;
  final VoidCallback onThemeToggle;
  final ValueChanged<AccentTheme> onAccentChange;
  final VoidCallback onLapsToggle;

  const StriveHomeScreen({
    super.key,
    required this.themePreference,
    required this.accentTheme,
    required this.showLaps,
    required this.onThemeToggle,
    required this.onAccentChange,
    required this.onLapsToggle,
  });

  @override
  State<StriveHomeScreen> createState() => _StriveHomeScreenState();
}

class _StriveHomeScreenState extends State<StriveHomeScreen> {
  // ── Data ─────────────────────────────────────────────────────
  List<StudySession> _sessions = [];
  bool _isLoading = true;

  // ── Timer ─────────────────────────────────────────────────────
  bool _isTimerActive = false;
  bool _isTimerPaused = false;
  DateTime? _activeSessionStart;
  Timer? _timer;
  int _secondsElapsed = 0;

  // ── Calendar ──────────────────────────────────────────────────
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;

  // ── Mini Mode ─────────────────────────────────────────────────
  bool _isMiniMode = false;

  static bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  // ─────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSessionHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCrashRecovery());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Mini Mode
  // ─────────────────────────────────────────────────────────────

  Future<void> _enterMiniMode() async {
    setState(() => _isMiniMode = true);
    if (_isDesktop) {
      // 1. Ensure resizable is true before attempting to change size
      await windowManager.setResizable(true);
      // 2. Clear minimum size constraints
      await windowManager.setMinimumSize(const Size(0, 0));
      // 3. Apply the new mini size
      await windowManager.setSize(_kMiniSize);
      
      // 4. Position the window
      try {
        final displays = ui.PlatformDispatcher.instance.displays;
        if (displays.isNotEmpty) {
          final display = displays.first;
          final screenWidth = display.size.width / display.devicePixelRatio;
          await windowManager.setPosition(
            Offset(screenWidth - _kMiniSize.width - 16, 16),
          );
        }
      } catch (_) {}

      // 5. Apply states like alwaysOnTop and lock resizability last
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setResizable(false);
    }
  }

  Future<void> _exitMiniMode() async {
    setState(() => _isMiniMode = false);
    if (_isDesktop) {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
      await windowManager.setSize(_kFullSize);
      await windowManager.setMinimumSize(const Size(950, 600));
      await windowManager.center();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Data Operations
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadSessionHistory() async {
    setState(() => _isLoading = true);
    final sessions = await SessionStorage.loadSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _saveSession(StudySession session) async {
    final updated = [session, ..._sessions];
    setState(() => _sessions = updated);
    await SessionStorage.saveSessions(updated);
  }

  Future<void> _clearDayRecords(DateTime day) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.get(isDark: isDark, accent: widget.accentTheme);
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final label = isToday ? 'today' : DateFormat('MMM d').format(day);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
          side: BorderSide(color: colors.border.withOpacity(0.4)),
        ),
        title: Text('Clear $label?',
            style: TextStyle(color: colors.foreground, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'This will permanently delete all focus sessions recorded for $label. This cannot be undone.',
          style: TextStyle(color: colors.muted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: colors.muted))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = _sessions
          .where((s) => !(s.startTime.year == day.year &&
              s.startTime.month == day.month &&
              s.startTime.day == day.day))
          .toList();
      setState(() => _sessions = updated);
      await SessionStorage.saveSessions(updated);
    }
  }

  Future<bool> _processImportString(String jsonText) async {
    try {
      final List<dynamic> decoded = jsonDecode(jsonText);
      final incoming = decoded.map((item) => StudySession.fromJson(item)).toList();
      final merged = SessionStorage.mergeSessions(_sessions, incoming);
      setState(() => _sessions = merged);
      await SessionStorage.saveSessions(merged);
      return true;
    } catch (e) {
      debugPrint('Import parsing error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Timer Operations
  // ─────────────────────────────────────────────────────────────

  Future<void> _startTimer() async {
    final active = StudySession.start(description: 'Study Session', startTime: DateTime.now());
    await SessionStorage.saveActiveSession(active);

    setState(() {
      _isTimerActive = true;
      _isTimerPaused = false;
      _activeSessionStart = active.startTime;
      _secondsElapsed = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTimerActive && !_isTimerPaused) {
        setState(() => _secondsElapsed++);
        if (_secondsElapsed % 5 == 0 && _activeSessionStart != null) {
          SessionStorage.saveActiveSession(StudySession(
            id: 'active',
            description: 'Study Session',
            startTime: _activeSessionStart!,
            endTime: DateTime.now(),
            durationSeconds: _secondsElapsed,
          ));
        }
      }
    });
  }

  Future<void> _pauseTimer() async {
    if (!_isTimerActive || _isTimerPaused) return;
    setState(() => _isTimerPaused = true);
    if (_activeSessionStart != null) {
      await SessionStorage.saveActiveSession(StudySession(
        id: 'active',
        description: 'Study Session',
        startTime: _activeSessionStart!,
        endTime: DateTime.now(),
        durationSeconds: _secondsElapsed,
      ));
    }
  }

  Future<void> _resumeTimer() async {
    if (!_isTimerActive || !_isTimerPaused) return;
    final adjustedStart = DateTime.now().subtract(Duration(seconds: _secondsElapsed));
    setState(() {
      _isTimerPaused = false;
      _activeSessionStart = adjustedStart;
    });
    await SessionStorage.saveActiveSession(
        StudySession.start(description: 'Study Session', startTime: adjustedStart));
  }

  Future<void> _stopTimer() async {
    if (_activeSessionStart == null) return;
    _timer?.cancel();

    final finalSession = StudySession(
      id: StudySession.generateUuid(),
      description: 'Study Session',
      startTime: _activeSessionStart!,
      endTime: DateTime.now(),
      durationSeconds: _secondsElapsed,
    );

    await _saveSession(finalSession);
    await SessionStorage.clearActiveSession();

    setState(() {
      _isTimerActive = false;
      _isTimerPaused = false;
      _activeSessionStart = null;
      _secondsElapsed = 0;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Crash Recovery
  // ─────────────────────────────────────────────────────────────

  Future<void> _checkCrashRecovery() async {
    final active = await SessionStorage.loadActiveSession();
    if (active == null) return;

    final elapsedSec = active.durationSeconds > 0
        ? active.durationSeconds
        : DateTime.now().difference(active.startTime).inSeconds;

    if (elapsedSec < 0) {
      await SessionStorage.clearActiveSession();
      return;
    }

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.get(isDark: isDark, accent: widget.accentTheme);

    await showCrashRecoveryDialog(
      context: context,
      colors: colors,
      session: active,
      elapsedSec: elapsedSec,
      onSave: _saveSession,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Utility Helpers
  // ─────────────────────────────────────────────────────────────

  String _formatSeconds(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
  }

  String _formatSessionDurationFriendly(int totalSeconds) {
    if (totalSeconds <= 0) return 'No Record';
    if (totalSeconds < 5 * 60) return 'less than 5 minutes';
    if (totalSeconds < 60) return '${totalSeconds}s';
    final mins = totalSeconds ~/ 60;
    if (mins < 60) return '${mins}m';
    final hours = mins ~/ 60;
    final remaining = mins % 60;
    return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
  }

  int _getSecondsForDay(DateTime day) {
    int total = _sessions
        .where((s) =>
            s.startTime.year == day.year &&
            s.startTime.month == day.month &&
            s.startTime.day == day.day)
        .fold<int>(0, (sum, s) => sum + s.durationSeconds);
    final now = DateTime.now();
    if (_isTimerActive && day.year == now.year && day.month == now.month && day.day == now.day) {
      total += _secondsElapsed;
    }
    return total;
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.get(isDark: isDark, accent: widget.accentTheme);
    return _isMiniMode ? _buildMiniView(colors) : _buildFullView(colors);
  }

  // ── Full view ─────────────────────────────────────────────────

  Widget _buildFullView(AppColors colors) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          TitleBar(
            themePreference: widget.themePreference,
            accentTheme: widget.accentTheme,
            onThemeToggle: widget.onThemeToggle,
            onAccentChange: widget.onAccentChange,
            colors: colors,
            onMiniMode: _enterMiniMode,
          ),
          Expanded(
            child: AnimatedContainer(
              duration: AppDesign.transitionDuration,
              curve: AppDesign.transitionCurve,
              color: colors.background,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: colors.focusAccent, strokeWidth: 2))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: TimerPanel(
                            colors: colors,
                            secondsElapsed: _secondsElapsed,
                            isTimerActive: _isTimerActive,
                            isTimerPaused: _isTimerPaused,
                            formatSeconds: _formatSeconds,
                            onStart: _startTimer,
                            onPause: _pauseTimer,
                            onResume: _resumeTimer,
                            onStop: _stopTimer,
                          ),
                        ),
                        if (!_isTimerActive)
                          VerticalDivider(width: 1, color: colors.border),
                        SidebarPanel(
                          colors: colors,
                          isTimerActive: _isTimerActive,
                          showLaps: widget.showLaps,
                          onLapsToggle: widget.onLapsToggle,
                          sessions: _sessions,
                          calendarMonth: _calendarMonth,
                          selectedDate: _selectedDate,
                          getSecondsForDay: _getSecondsForDay,
                          formatDurationFriendly: _formatSessionDurationFriendly,
                          onDaySelected: (day) => setState(() => _selectedDate = day),
                          onMonthChanged: (month) => setState(() => _calendarMonth = month),
                          onClearDay: _clearDayRecords,
                          onGoToToday: () => setState(() => _selectedDate = DateTime.now()),
                          onExport: () => showExportDialog(context: context, colors: colors),
                          onImport: () => showImportDialog(
                            context: context,
                            colors: colors,
                            onImport: _processImportString,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mini floating timer bar ────────────────────────────────────

  Widget _buildMiniView(AppColors colors) {
    final isActive = _isTimerActive && !_isTimerPaused;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) async {
          if (_isDesktop) await windowManager.startDragging();
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border.all(color: colors.border.withOpacity(0.8), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left accent bar — glows accent color when focus is active
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 3,
                height: double.infinity,
                color: isActive
                    ? colors.focusAccent
                    : colors.border.withOpacity(0.4),
              ),

              const SizedBox(width: 16),

              // Status dot
              _MiniStatusDot(isActive: isActive, colors: colors),

              const SizedBox(width: 12),

              // Labels + timer stacked
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive
                          ? 'FOCUS IN PROGRESS'
                          : (_isTimerPaused ? 'PAUSED' : 'STRIVE'),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: isActive
                            ? colors.focusAccent
                            : colors.foreground.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSeconds(_secondsElapsed),
                      style: AppDesign.getTimerStyle(colors).copyWith(
                        fontSize: 26,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Controls
              if (_isTimerActive) ...[
                _MiniIconButton(
                  icon: _isTimerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: colors.primary,
                  tooltip: _isTimerPaused ? 'Resume' : 'Pause',
                  onTap: _isTimerPaused ? _resumeTimer : _pauseTimer,
                ),
                _MiniIconButton(
                  icon: Icons.stop_rounded,
                  color: colors.softRedText,
                  tooltip: 'Stop & Save',
                  onTap: _stopTimer,
                ),
              ] else
                _MiniIconButton(
                  icon: Icons.play_arrow_rounded,
                  color: colors.primary,
                  tooltip: 'Start Focus',
                  onTap: _startTimer,
                ),

              Container(
                width: 1,
                height: 20,
                color: colors.border.withOpacity(0.5),
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),

              // Expand
              _MiniIconButton(
                icon: Icons.open_in_full_rounded,
                color: colors.foreground.withOpacity(0.7),
                tooltip: 'Expand to full view',
                onTap: _exitMiniMode,
              ),

              // Close
              _MiniIconButton(
                icon: Icons.close_rounded,
                color: Colors.redAccent.withOpacity(0.8),
                tooltip: 'Close Strive',
                onTap: () async => windowManager.close(),
              ),

              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini mode helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MiniStatusDot extends StatefulWidget {
  final bool isActive;
  final AppColors colors;
  const _MiniStatusDot({required this.isActive, required this.colors});

  @override
  State<_MiniStatusDot> createState() => _MiniStatusDotState();
}

class _MiniStatusDotState extends State<_MiniStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.colors.focusAccent
              .withOpacity(0.5 + _ctrl.value * 0.5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.colors.focusAccent.withOpacity(_ctrl.value * 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
