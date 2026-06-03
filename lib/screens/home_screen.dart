import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system.dart';
import '../session_model.dart';
import '../session_storage.dart';
import '../dialogs/crash_recovery_dialog.dart';
import '../dialogs/export_dialog.dart';
import '../dialogs/import_dialog.dart';
import '../widgets/title_bar.dart';
import '../widgets/timer_panel.dart';
import '../widgets/sidebar_panel.dart';

class StriveHomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const StriveHomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
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
    final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: TextStyle(color: colors.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = _sessions
          .where((s) => !(s.startTime.year == day.year && s.startTime.month == day.month && s.startTime.day == day.day))
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
        // Persist active session every 5 seconds (crash recovery)
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
    final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;

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
        .where((s) => s.startTime.year == day.year && s.startTime.month == day.month && s.startTime.day == day.day)
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
    final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          TitleBar(
            isDarkMode: widget.isDarkMode,
            onThemeToggle: widget.onThemeToggle,
            colors: colors,
          ),
          Expanded(
            child: AnimatedContainer(
              duration: AppDesign.transitionDuration,
              curve: AppDesign.transitionCurve,
              color: colors.background,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.focusAccent, strokeWidth: 2))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left: Timer
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

                        // Divider (hidden during focus)
                        if (!_isTimerActive)
                          VerticalDivider(width: 1, color: colors.border),

                        // Right: Sidebar
                        SidebarPanel(
                          colors: colors,
                          isTimerActive: _isTimerActive,
                          sessions: _sessions,
                          calendarMonth: _calendarMonth,
                          selectedDate: _selectedDate,
                          getSecondsForDay: _getSecondsForDay,
                          formatDurationFriendly: _formatSessionDurationFriendly,
                          onDaySelected: (day) => setState(() => _selectedDate = day),
                          onMonthChanged: (month) => setState(() => _calendarMonth = month),
                          onClearDay: _clearDayRecords,
                          onGoToToday: () => setState(() => _selectedDate = DateTime.now()),
                          onExport: () {
                            final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;
                            showExportDialog(context: context, colors: colors);
                          },
                          onImport: () {
                            final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;
                            showImportDialog(
                              context: context,
                              colors: colors,
                              onImport: _processImportString,
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
