import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';

import 'design_system.dart';
import 'session_model.dart';
import 'session_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window_manager on supported desktop platforms
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
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
  bool _isDarkMode = true;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
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
  // Navigation State
  String _currentTab = 'timer'; // 'timer' or 'history'

  // Data State
  List<StudySession> _sessions = [];
  bool _isLoading = true;

  // Active Timer State
  bool _isTimerActive = false;
  DateTime? _activeSessionStart;
  Timer? _timer;
  int _secondsElapsed = 0;

  // Form Input State
  final TextEditingController _objectiveController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSessionHistory();
    // Schedule crash recovery check after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCrashRecovery();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _objectiveController.dispose();
    super.dispose();
  }

  // Load study history from local storage
  Future<void> _loadSessionHistory() async {
    setState(() {
      _isLoading = true;
    });
    final sessions = await SessionStorage.loadSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  // Check if there was an interrupted session on app startup
  Future<void> _checkCrashRecovery() async {
    final active = await SessionStorage.loadActiveSession();
    if (active != null) {
      final elapsedSec = DateTime.now().difference(active.startTime).inSeconds;
      if (elapsedSec < 0) {
        // Clock skew or invalid start time, just clear
        await SessionStorage.clearActiveSession();
        return;
      }
      
      final elapsedFormatted = _formatSeconds(elapsedSec);
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;
          return AlertDialog(
            backgroundColor: colors.card,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
              side: BorderSide(color: colors.border, width: 1),
            ),
            title: Text(
              'Interrupted Session Found ⚠️',
              style: AppDesign.getAppHeaderStyle(colors),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strive detected an interrupted study session. Would you like to save this focus block or discard it?',
                  style: AppDesign.getLogFeedStyle(colors).copyWith(color: colors.muted),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active.description.isNotEmpty ? active.description : 'Untitled focus objective',
                        style: AppDesign.getLogFeedStyle(colors).copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Started: ${DateFormat('MMM d, h:mm a').format(active.startTime)}',
                        style: AppDesign.getBodyMutedStyle(colors),
                      ),
                      Text(
                        'Elapsed Duration: $elapsedFormatted',
                        style: AppDesign.getBodyMutedStyle(colors),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await SessionStorage.clearActiveSession();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  'Discard',
                  style: AppDesign.getLogFeedStyle(colors).copyWith(color: colors.muted),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final completed = active.complete(DateTime.now());
                  await _saveSession(completed);
                  await SessionStorage.clearActiveSession();
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                child: Text(
                  'Save Session',
                  style: AppDesign.getLogFeedStyle(colors).copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  // Save a completed session
  Future<void> _saveSession(StudySession session) async {
    final updated = List<StudySession>.from(_sessions);
    updated.insert(0, session);
    setState(() {
      _sessions = updated;
    });
    await SessionStorage.saveSessions(updated);
  }

  // Start the Focus Timer
  Future<void> _startTimer() async {
    // Create and save active session state for crash recovery
    final active = StudySession.start(
      description: _objectiveController.text.trim(),
      startTime: DateTime.now(),
    );
    
    await SessionStorage.saveActiveSession(active);

    setState(() {
      _isTimerActive = true;
      _activeSessionStart = active.startTime;
      _secondsElapsed = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeSessionStart != null) {
        setState(() {
          _secondsElapsed = DateTime.now().difference(_activeSessionStart!).inSeconds;
        });
      }
    });
  }

  // Stop the Focus Timer and save
  Future<void> _stopTimer() async {
    if (_activeSessionStart == null) return;
    _timer?.cancel();

    final endTime = DateTime.now();

    // Build the finalized session object
    final finalSession = StudySession(
      id: StudySession.generateUuid(),
      description: _objectiveController.text.trim().isNotEmpty 
          ? _objectiveController.text.trim()
          : 'Untitled session',
      startTime: _activeSessionStart!,
      endTime: endTime,
      durationSeconds: endTime.difference(_activeSessionStart!).inSeconds,
    );

    // Save completed session and clear active temp state
    await _saveSession(finalSession);
    await SessionStorage.clearActiveSession();

    setState(() {
      _isTimerActive = false;
      _activeSessionStart = null;
      _secondsElapsed = 0;
      _objectiveController.clear();
    });
  }

  // Utility to format seconds into MM:SS or HH:MM:SS
  String _formatSeconds(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String minStr = minutes.toString().padLeft(2, '0');
    final String secStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minStr:$secStr';
    } else {
      return '$minStr:$secStr';
    }
  }

  // Format total seconds into human friendly text (e.g. 1.2 hrs or 45 mins)
  String _formatSessionDurationFriendly(int totalSeconds) {
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final int mins = totalSeconds ~/ 60;
    if (mins < 60) {
      return '${mins}m';
    }
    final int hours = mins ~/ 60;
    final int remainingMins = mins % 60;
    if (remainingMins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMins}m';
  }

  // Friendly Date Time Formatter
  String _formatSessionDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(dt.year, dt.month, dt.day);

    final timeStr = DateFormat('h:mm a').format(dt);
    if (dateToCheck == today) {
      return 'Today at $timeStr';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday at $timeStr';
    } else {
      return '${DateFormat('MMM d').format(dt)} at $timeStr';
    }
  }

  // Calculate statistics
  double get _totalFocusHours {
    if (_sessions.isEmpty) return 0.0;
    final totalSecs = _sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    return totalSecs / 3600.0;
  }

  double get _avgSessionMinutes {
    if (_sessions.isEmpty) return 0.0;
    final totalSecs = _sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);
    return (totalSecs / _sessions.length) / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;

    return Scaffold(
      backgroundColor: Colors.transparent, // transparent background for custom window frame
      body: Column(
        children: [
          // 1. Draggable Window Title Bar
          TitleBar(
            isDarkMode: widget.isDarkMode,
            onThemeToggle: widget.onThemeToggle,
            colors: colors,
          ),
          
          // 2. Main Columns Layout
          Expanded(
            child: AnimatedContainer(
              duration: AppDesign.transitionDuration,
              curve: AppDesign.transitionCurve,
              color: colors.background,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Column 1: Left Sidebar (collapses to 0 width in active focus)
                  AnimatedContainer(
                    duration: AppDesign.transitionDuration,
                    curve: AppDesign.transitionCurve,
                    width: _isTimerActive ? 0 : 240,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: _isTimerActive ? Colors.transparent : colors.border,
                          width: 1,
                        ),
                      ),
                    ),
                    child: _buildLeftSidebar(colors),
                  ),

                  // Column 2: Central Workspace (Always takes remaining space)
                  Expanded(
                    child: _buildCentralWorkspace(colors),
                  ),

                  // Column 3: Right Sidebar (collapses to 0 width in active focus)
                  AnimatedContainer(
                    duration: AppDesign.transitionDuration,
                    curve: AppDesign.transitionCurve,
                    width: _isTimerActive ? 0 : 300,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: _isTimerActive ? Colors.transparent : colors.border,
                          width: 1,
                        ),
                      ),
                    ),
                    child: _buildRightSidebar(colors),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // BUILD: Left Sidebar Navigation
  Widget _buildLeftSidebar(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Navigation View Selector
          Text('NAVIGATION', style: AppDesign.getWidgetHeaderStyle(colors)),
          const SizedBox(height: 12),
          _buildNavigationTabButton('Timer View', 'timer', Icons.timer_outlined, colors),
          const SizedBox(height: 8),
          _buildNavigationTabButton('History Logs', 'history', Icons.history_outlined, colors),
        ],
      ),
    );
  }

  // Navigation tab helper
  Widget _buildNavigationTabButton(String label, String tabId, IconData icon, AppColors colors) {
    final isSelected = _currentTab == tabId;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _currentTab = tabId;
          });
        },
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
            border: Border.all(
              color: isSelected ? colors.border : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? colors.primary : colors.muted,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppDesign.getLogFeedStyle(colors).copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colors.foreground : colors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // BUILD: Central Workspace (Timer active layout / Timer idle layout / History logs layout)
  Widget _buildCentralWorkspace(AppColors colors) {
    if (_currentTab == 'history') {
      return _buildHistoryLogsView(colors);
    }

    // Timer Active Focus State
    if (_isTimerActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Floating tag for objective
            if (_objectiveController.text.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Text(
                  _objectiveController.text.trim(),
                  style: AppDesign.getBodyMutedStyle(colors).copyWith(
                    fontStyle: FontStyle.italic,
                    color: colors.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Digital clock (monospaced)
            Text(
              _formatSeconds(_secondsElapsed),
              style: AppDesign.getTimerStyle(colors).copyWith(fontSize: 72),
            ),
            
            const SizedBox(height: 8),
            Text(
              'KEEP FOCUSING',
              style: AppDesign.getWidgetHeaderStyle(colors).copyWith(letterSpacing: 2.0),
            ),
            
            const SizedBox(height: 48),

            // Red Stop focus CTA
            ElevatedButton(
              onPressed: _stopTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.softRedBg,
                foregroundColor: colors.softRedText,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                  side: BorderSide(color: colors.softRedBorder, width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, size: 18, color: colors.softRedText),
                  const SizedBox(width: 8),
                  Text(
                    'Stop Focus Session',
                    style: AppDesign.getLogFeedStyle(colors).copyWith(
                      color: colors.softRedText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Timer Idle State Layout
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'START STUDY SESSION',
            style: AppDesign.getWidgetHeaderStyle(colors),
          ),
          const SizedBox(height: 16),

          // Objective Input Box
          TextField(
            controller: _objectiveController,
            style: AppDesign.getLogFeedStyle(colors),
            decoration: InputDecoration(
              hintText: 'What are you studying?',
              hintStyle: AppDesign.getBodyMutedStyle(colors),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: colors.card,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.border, width: 1),
                borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: colors.ring, width: 1.5),
                borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Button Area
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _startTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 18, color: colors.onPrimary),
                    const SizedBox(width: 6),
                    Text(
                      'Start Session',
                      style: AppDesign.getLogFeedStyle(colors).copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),
          
          // Section: Recent Logs (shows last 3-5 sessions)
          Text(
            'RECENT FOCUS SESSIONS',
            style: AppDesign.getWidgetHeaderStyle(colors),
          ),
          const SizedBox(height: 16),

          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : _sessions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: Text(
                          'No recent study sessions recorded.',
                          style: AppDesign.getBodyMutedStyle(colors),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessions.length > 5 ? 5 : _sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return _buildSessionLogCard(session, colors);
                      },
                    ),
        ],
      ),
    );
  }

  // BUILD: Detailed full History view
  Widget _buildHistoryLogsView(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FOCUS HISTORY LOGS',
                    style: AppDesign.getWidgetHeaderStyle(colors),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review all completed study blocks',
                    style: AppDesign.getBodyMutedStyle(colors),
                  ),
                ],
              ),
              const Spacer(),
              // Delete history button if user wants to clear
              if (_sessions.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    // Confirm clear dialog
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: colors.card,
                          surfaceTintColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
                            side: BorderSide(color: colors.border),
                          ),
                          title: Text('Clear History', style: AppDesign.getAppHeaderStyle(colors)),
                          content: Text('Are you sure you want to delete all study history? This cannot be undone.', style: AppDesign.getLogFeedStyle(colors)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel', style: TextStyle(color: colors.muted)),
                            ),
                            TextButton(
                              onPressed: () async {
                                setState(() {
                                  _sessions = [];
                                });
                                await SessionStorage.saveSessions([]);
                                if (context.mounted) Navigator.pop(context);
                              },
                              child: const Text('Delete All', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Clear All', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 48, color: colors.muted.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No study sessions found.',
                              style: AppDesign.getBodyMutedStyle(colors),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          return _buildSessionLogCard(session, colors);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Session Feed Card widget
  Widget _buildSessionLogCard(StudySession session, AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
        border: Border.all(color: colors.border, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Accent Bar (thin vertical accent bar runs along left edge)
            Container(
              width: 4,
              color: AppColors.focusAccent,
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Start Time Date
                          Text(
                            _formatSessionDateTime(session.startTime),
                            style: AppDesign.getBodyMutedStyle(colors).copyWith(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          // Session Objective description
                          Text(
                            session.description,
                            style: AppDesign.getLogFeedStyle(colors).copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Duration display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.border, width: 0.5),
                      ),
                      child: Text(
                        _formatSessionDurationFriendly(session.durationSeconds),
                        style: AppDesign.getLogFeedStyle(colors).copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // Inline Delete button
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 16, color: colors.muted),
                      onPressed: () {
                        // Confirm individual delete
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              backgroundColor: colors.card,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
                                side: BorderSide(color: colors.border),
                              ),
                              title: Text('Delete Session', style: AppDesign.getAppHeaderStyle(colors)),
                              content: Text('Are you sure you want to delete this study block?', style: AppDesign.getLogFeedStyle(colors)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel', style: TextStyle(color: colors.muted)),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final updated = List<StudySession>.from(_sessions)..removeWhere((s) => s.id == session.id);
                                    setState(() {
                                      _sessions = updated;
                                    });
                                    await SessionStorage.saveSessions(updated);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BUILD: Right Sidebar (Analytics & Consistency Heat Map)
  Widget _buildRightSidebar(AppColors colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Performance Summary
          Text('PERFORMANCE SUMMARY', style: AppDesign.getWidgetHeaderStyle(colors)),
          const SizedBox(height: 16),
          
          // Total Hours focused
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_totalFocusHours.toStringAsFixed(1)} hrs',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Total Focus Hours', style: AppDesign.getBodyMutedStyle(colors)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Average Session Time
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_avgSessionMinutes.toStringAsFixed(0)} mins',
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Avg. Session Duration', style: AppDesign.getBodyMutedStyle(colors)),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Section: Activity Heat Map (Grid representing days of the week over past weeks)
          Text('ACTIVITY MAP (4 WEEKS)', style: AppDesign.getWidgetHeaderStyle(colors)),
          const SizedBox(height: 16),
          
          _buildActivityHeatMap(colors),
          
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: AppDesign.getBodyMutedStyle(colors).copyWith(fontSize: 10)),
              const SizedBox(width: 4),
              _buildLegendBox(colors.border),
              const SizedBox(width: 3),
              _buildLegendBox(AppColors.focusAccent.withOpacity(0.3)),
              const SizedBox(width: 3),
              _buildLegendBox(AppColors.focusAccent.withOpacity(0.65)),
              const SizedBox(width: 3),
              _buildLegendBox(AppColors.focusAccent),
              const SizedBox(width: 4),
              Text('More', style: AppDesign.getBodyMutedStyle(colors).copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  // Small legend grid cell box
  Widget _buildLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // 4 Weeks activity heat map grid builder (Mon to Sun columns, 4 rows of weeks)
  Widget _buildActivityHeatMap(AppColors colors) {
    final now = DateTime.now();
    
    // Find the Monday of the current week
    final weekdayOffset = now.weekday - 1; // 0 for Mon, 6 for Sun
    final mondayThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekdayOffset));
    
    // Starting date: 3 weeks prior to Monday of this week
    final startDate = mondayThisWeek.subtract(const Duration(days: 21));

    // Construct 4 rows of 7 days
    final List<List<DateTime>> weeksGrid = [];
    for (int week = 0; week < 4; week++) {
      final List<DateTime> currentWeekDays = [];
      for (int day = 0; day < 7; day++) {
        currentWeekDays.add(startDate.add(Duration(days: week * 7 + day)));
      }
      weeksGrid.add(currentWeekDays);
    }

    // Days label header
    final List<String> daysLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Days indicator header (M T W T F S S)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: daysLabels.map((lbl) => Expanded(
            child: Text(
              lbl,
              textAlign: TextAlign.center,
              style: AppDesign.getBodyMutedStyle(colors).copyWith(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          )).toList(),
        ),
        const SizedBox(height: 6),

        // Grid Rows
        Column(
          children: weeksGrid.map((weekDays) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: weekDays.map((dayDate) {
                  // Calculate total focus time on this day
                  final secondsStudied = _sessions
                      .where((s) => 
                          s.startTime.year == dayDate.year &&
                          s.startTime.month == dayDate.month &&
                          s.startTime.day == dayDate.day
                      )
                      .fold<int>(0, (sum, s) => sum + s.durationSeconds);
                      
                  return Expanded(
                    child: Tooltip(
                      message: '${DateFormat('MMM d, yyyy').format(dayDate)}: ${_formatSessionDurationFriendly(secondsStudied)} focus',
                      child: Container(
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 3.0),
                        decoration: BoxDecoration(
                          color: _getHeatMapColor(secondsStudied, colors),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day
                                ? colors.ring
                                : colors.border.withOpacity(0.5),
                            width: dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day ? 1.5 : 0.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Returns shade color based on total study seconds
  Color _getHeatMapColor(int seconds, AppColors colors) {
    if (seconds <= 0) {
      return colors.card; // empty day
    }
    
    // Base focus accent color
    final Color baseAccent = AppColors.focusAccent;

    final int minutes = seconds ~/ 60;
    if (minutes < 15) {
      return baseAccent.withOpacity(0.20);
    } else if (minutes < 45) {
      return baseAccent.withOpacity(0.55);
    } else {
      return baseAccent; // deep focus completed
    }
  }
}

// -------------------------------------------------------------
// TITLE BAR: Custom Frameless Header
// -------------------------------------------------------------
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
        border: Border(
          bottom: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // App Icon & Title
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
                child: Row(
                  children: [
                    Text(
                      'Strive 🚀',
                      style: AppDesign.getAppHeaderStyle(colors),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Theme Toggle Button
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 16,
              color: colors.foreground,
            ),
            tooltip: 'Toggle Visual Theme',
            onPressed: onThemeToggle,
            splashRadius: 18,
          ),

          // Divider
          if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) ...[
            Container(
              width: 1,
              height: 20,
              color: colors.border,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            // Minimize
            IconButton(
              icon: Icon(Icons.remove, size: 14, color: colors.foreground),
              onPressed: () async {
                await windowManager.minimize();
              },
              splashRadius: 18,
              tooltip: 'Minimize',
            ),
            // Maximize / Restore
            IconButton(
              icon: Icon(Icons.crop_square, size: 12, color: colors.foreground),
              onPressed: () async {
                bool isMax = await windowManager.isMaximized();
                if (isMax) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              splashRadius: 18,
              tooltip: 'Maximize',
            ),
            // Close
            IconButton(
              icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
              onPressed: () async {
                await windowManager.close();
              },
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
