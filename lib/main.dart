import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
    setState(() {
      _isDarkMode = isDark;
    });
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
  // Data State
  List<StudySession> _sessions = [];
  bool _isLoading = true;

  // Active Timer State
  bool _isTimerActive = false;
  bool _isTimerPaused = false;
  DateTime? _activeSessionStart;
  Timer? _timer;
  int _secondsElapsed = 0;

  // Heatmap Calendar & Date Selection State
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;

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
      final elapsedSec = active.durationSeconds > 0 
          ? active.durationSeconds 
          : DateTime.now().difference(active.startTime).inSeconds;
          
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
                        'Interrupted Session',
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
                  // Override completed duration to match crash recovered time
                  final finalCompleted = StudySession(
                    id: completed.id,
                    description: completed.description,
                    startTime: completed.startTime,
                    endTime: completed.endTime,
                    durationSeconds: elapsedSec,
                  );
                  await _saveSession(finalCompleted);
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

  // Delete all sessions for a specific day (with confirmation dialog)
  Future<void> _clearDayRecords(DateTime day) async {
    final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;
    final isToday = day.year == DateTime.now().year &&
        day.month == DateTime.now().month &&
        day.day == DateTime.now().day;
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
        title: Text(
          'Clear $label?',
          style: TextStyle(color: colors.foreground, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'This will permanently delete all focus sessions recorded for $label. This cannot be undone.',
          style: TextStyle(color: colors.muted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = _sessions.where((s) =>
        !(s.startTime.year == day.year &&
          s.startTime.month == day.month &&
          s.startTime.day == day.day)
      ).toList();
      setState(() => _sessions = updated);
      await SessionStorage.saveSessions(updated);
    }
  }

  // Export JSON backups (clipboard and file export)
  void _showExportDialog() async {
    final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;
    final jsonStr = await SessionStorage.exportToJsonString();
    final pathController = TextEditingController();
    
    try {
      final docDir = await getApplicationDocumentsDirectory();
      pathController.text = '${docDir.path}/strive_backup.json';
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        String statusMessage = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
                side: BorderSide(color: colors.border, width: 1),
              ),
              title: Text(
                'Export Session History',
                style: AppDesign.getAppHeaderStyle(colors).copyWith(fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup your study sessions either by copying the data to your clipboard or saving to a local JSON file.',
                    style: AppDesign.getLogFeedStyle(colors).copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: 16),
                  
                  // Copy to clipboard option
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: jsonStr));
                      setDialogState(() {
                        statusMessage = '✅ JSON backup copied to clipboard!';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary.withOpacity(0.08),
                      foregroundColor: colors.primary,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                        side: BorderSide(color: colors.border, width: 1),
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy JSON Data to Clipboard', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Save to path option
                  Text(
                    'Save to Local File Path:',
                    style: AppDesign.getLogFeedStyle(colors).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pathController,
                    style: TextStyle(color: colors.foreground, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '/path/to/backup.json',
                      hintStyle: TextStyle(color: colors.muted),
                      filled: true,
                      fillColor: colors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                        borderSide: const BorderSide(color: AppColors.focusAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final path = pathController.text.trim();
                      if (path.isEmpty) {
                        setDialogState(() {
                          statusMessage = '❌ Please enter a valid path.';
                        });
                        return;
                      }
                      try {
                        final file = File(path);
                        await file.parent.create(recursive: true);
                        await file.writeAsString(jsonStr);
                        setDialogState(() {
                          statusMessage = '✅ Saved successfully to:\n$path';
                        });
                      } catch (e) {
                        setDialogState(() {
                          statusMessage = '❌ Error writing file:\n${e.toString()}';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Save to Path', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  
                  if (statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      statusMessage,
                      style: AppDesign.getBodyMutedStyle(colors).copyWith(
                        color: statusMessage.contains('✅') ? AppColors.focusAccent : Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(color: colors.foreground)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Import JSON backups (clipboard and file load)
  void _showImportDialog() {
    final colors = widget.isDarkMode ? AppColors.dark : AppColors.light;
    final pathController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        String statusMessage = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
                side: BorderSide(color: colors.border, width: 1),
              ),
              title: Text(
                'Import Session History',
                style: AppDesign.getAppHeaderStyle(colors).copyWith(fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import a Strive session backup. This will merge sessions and prevent duplicate entries automatically.',
                    style: AppDesign.getLogFeedStyle(colors).copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: 16),
                  
                  // Paste option
                  ElevatedButton.icon(
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
                      final text = clipboardData?.text ?? '';
                      if (text.trim().isEmpty) {
                        setDialogState(() {
                          statusMessage = '❌ Clipboard is empty or contains no text.';
                        });
                        return;
                      }
                      
                      final success = await _processImportString(text);
                      if (success) {
                        setDialogState(() {
                          statusMessage = '✅ Successfully imported & merged data!';
                        });
                      } else {
                        setDialogState(() {
                          statusMessage = '❌ Invalid format. Please check JSON data.';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary.withOpacity(0.08),
                      foregroundColor: colors.primary,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                        side: BorderSide(color: colors.border, width: 1),
                      ),
                    ),
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('Paste & Import from Clipboard', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Load from path option
                  Text(
                    'Load from Local File Path:',
                    style: AppDesign.getLogFeedStyle(colors).copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pathController,
                    style: TextStyle(color: colors.foreground, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '/path/to/backup.json',
                      hintStyle: TextStyle(color: colors.muted),
                      filled: true,
                      fillColor: colors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                        borderSide: const BorderSide(color: AppColors.focusAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final path = pathController.text.trim();
                      if (path.isEmpty) {
                        setDialogState(() {
                          statusMessage = '❌ Please enter a valid path.';
                        });
                        return;
                      }
                      
                      try {
                        final file = File(path);
                        if (!await file.exists()) {
                          setDialogState(() {
                            statusMessage = '❌ File does not exist at this path.';
                          });
                          return;
                        }
                        
                        final text = await file.readAsString();
                        final success = await _processImportString(text);
                        if (success) {
                          setDialogState(() {
                            statusMessage = '✅ Successfully imported & merged file data!';
                          });
                        } else {
                          setDialogState(() {
                            statusMessage = '❌ Invalid format. Please check JSON file content.';
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          statusMessage = '❌ Error reading file:\n${e.toString()}';
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Load & Import from File', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  
                  if (statusMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      statusMessage,
                      style: AppDesign.getBodyMutedStyle(colors).copyWith(
                        color: statusMessage.contains('✅') ? AppColors.focusAccent : Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close', style: TextStyle(color: colors.foreground)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Parse imported JSON and update sessions
  Future<bool> _processImportString(String jsonText) async {
    try {
      final List<dynamic> decoded = jsonDecode(jsonText);
      final incomingSessions = decoded.map((item) => StudySession.fromJson(item)).toList();
      
      final merged = SessionStorage.mergeSessions(_sessions, incomingSessions);
      
      setState(() {
        _sessions = merged;
      });
      
      await SessionStorage.saveSessions(merged);
      return true;
    } catch (e) {
      debugPrint('Import parsing error: $e');
      return false;
    }
  }

  // Start the Focus Timer
  Future<void> _startTimer() async {
    final active = StudySession.start(
      description: 'Study Session',
      startTime: DateTime.now(),
    );
    
    await SessionStorage.saveActiveSession(active);

    setState(() {
      _isTimerActive = true;
      _isTimerPaused = false;
      _activeSessionStart = active.startTime;
      _secondsElapsed = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTimerActive && !_isTimerPaused) {
        setState(() {
          _secondsElapsed++;

        });
        
        // Save active session state periodically (every 5 seconds) to prevent focus data loss
        if (_secondsElapsed % 5 == 0 && _activeSessionStart != null) {
          final active = StudySession(
            id: 'active',
            description: 'Study Session',
            startTime: _activeSessionStart!,
            endTime: DateTime.now(),
            durationSeconds: _secondsElapsed,
          );
          SessionStorage.saveActiveSession(active);
        }
      }
    });
  }

  // Pause the running timer
  Future<void> _pauseTimer() async {
    if (!_isTimerActive || _isTimerPaused) return;

    setState(() {
      _isTimerPaused = true;
    });

    // Save active session state in case of crash, encoding current elapsed time
    if (_activeSessionStart != null) {
      final active = StudySession(
        id: 'active',
        description: 'Study Session',
        startTime: _activeSessionStart!,
        endTime: DateTime.now(),
        durationSeconds: _secondsElapsed,
      );
      await SessionStorage.saveActiveSession(active);
    }
  }

  // Resume the paused timer
  Future<void> _resumeTimer() async {
    if (!_isTimerActive || !_isTimerPaused) return;

    // Rebase the start date to match current elapsed running seconds
    final adjustedStart = DateTime.now().subtract(Duration(seconds: _secondsElapsed));

    setState(() {
      _isTimerPaused = false;
      _activeSessionStart = adjustedStart;
    });

    // Save updated start time configuration
    final active = StudySession.start(
      description: 'Study Session',
      startTime: adjustedStart,
    );
    await SessionStorage.saveActiveSession(active);
  }

  // Stop the Focus Timer and save
  Future<void> _stopTimer() async {
    if (_activeSessionStart == null) return;
    _timer?.cancel();

    final endTime = DateTime.now();

    // Build the finalized session object
    final finalSession = StudySession(
      id: StudySession.generateUuid(),
      description: 'Study Session',
      startTime: _activeSessionStart!,
      endTime: endTime,
      durationSeconds: _secondsElapsed,
    );

    // Save completed session and clear active temp state
    await _saveSession(finalSession);
    await SessionStorage.clearActiveSession();

    setState(() {
      _isTimerActive = false;
      _isTimerPaused = false;
      _activeSessionStart = null;
      _secondsElapsed = 0;


    });
  }

  // Monitor break suggestions


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

  // Format total seconds into human friendly text (e.g. 1h 30m or 45m)
  String _formatSessionDurationFriendly(int totalSeconds) {
    if (totalSeconds <= 0) return 'No Record';
    if (totalSeconds < 5 * 60) {
      return 'less than 5 minutes';
    }
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

  // Group session data by day (local time)
  Map<String, int> _groupSessionsByDay() {
    final Map<String, int> dayMap = {};
    for (var session in _sessions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(session.startTime.toLocal());
      dayMap[dateStr] = (dayMap[dateStr] ?? 0) + session.durationSeconds;
    }
    return dayMap;
  }

  // Calculate today's focused seconds
  int get _secondsToday {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final dayMap = _groupSessionsByDay();
    int savedToday = dayMap[todayStr] ?? 0;
    if (_isTimerActive) {
      savedToday += _secondsElapsed;
    }
    return savedToday;
  }

  // Calculate daily average focused seconds
  int get _avgDailySeconds {
    final dayMap = _groupSessionsByDay();
    if (_isTimerActive) {
      final nowStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      dayMap[nowStr] = (dayMap[nowStr] ?? 0) + _secondsElapsed;
    }
    if (dayMap.isEmpty) return 0;
    final totalSec = dayMap.values.fold<int>(0, (sum, val) => sum + val);
    return totalSec ~/ dayMap.length;
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
              child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: AppColors.focusAccent, strokeWidth: 2))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Column 1: Focus Timer Engine (Takes remaining space)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              
                              // Large Digital Clock
                              Text(
                                _formatSeconds(_secondsElapsed),
                                style: AppDesign.getTimerStyle(colors).copyWith(fontSize: 96),
                              ),
                              const SizedBox(height: 12),
                              
                              Text(
                                _isTimerActive
                                    ? (_isTimerPaused ? 'SESSION PAUSED' : 'FOCUS IN PROGRESS')
                                    : 'READY TO FOCUS',
                                style: AppDesign.getWidgetHeaderStyle(colors).copyWith(
                                  letterSpacing: 2.0,
                                  color: _isTimerActive && !_isTimerPaused ? AppColors.focusAccent : colors.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 48),

                              // Play / Pause / Stop Buttons Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_isTimerActive) ...[
                                    // Start Focus Button
                                    ElevatedButton(
                                      onPressed: _startTimer,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.primary,
                                        foregroundColor: colors.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow_rounded, size: 22, color: colors.onPrimary),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Start Focus',
                                            style: AppDesign.getLogFeedStyle(colors).copyWith(
                                              color: colors.onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    // Pause / Resume Button
                                    ElevatedButton(
                                      onPressed: _isTimerPaused ? _resumeTimer : _pauseTimer,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.primary.withOpacity(0.08),
                                        foregroundColor: colors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                                          side: BorderSide(color: colors.border, width: 1),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        elevation: 0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isTimerPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                            size: 20,
                                            color: colors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isTimerPaused ? 'Resume' : 'Pause',
                                            style: AppDesign.getLogFeedStyle(colors).copyWith(
                                              color: colors.foreground,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Stop & Save Button
                                    ElevatedButton(
                                      onPressed: _stopTimer,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.softRedBg,
                                        foregroundColor: colors.softRedText,
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
                                          Icon(Icons.stop_rounded, size: 20, color: colors.softRedText),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Stop & Save',
                                            style: AppDesign.getLogFeedStyle(colors).copyWith(
                                              color: colors.softRedText,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                            ],
                          ),
                        ),
                      ),

                      // vertical divider line
                      if (!_isTimerActive)
                        VerticalDivider(width: 1, color: colors.border),

                      // Column 2: Performance analytics, heatmap, and daily logs (Collapsible)
                      AnimatedContainer(
                        duration: AppDesign.transitionDuration,
                        curve: AppDesign.transitionCurve,
                        width: _isTimerActive ? 0 : 400,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: colors.card,
                          border: Border(
                            left: BorderSide(
                              color: _isTimerActive ? Colors.transparent : colors.border,
                              width: 1,
                            ),
                          ),
                        ),
                        child: OverflowBox(
                          minWidth: 400,
                          maxWidth: 400,
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 400, // Fixed width inside the AnimatedContainer to prevent wrapping/flickering
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Heatmap section (fixed at top, natural size)
                                _buildActivityHeatMap(colors),
                                
                                const SizedBox(height: 12),
                                // Heatmap Legend
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
                                const SizedBox(height: 24),
                                Container(
                                  height: 1,
                                  color: colors.border.withOpacity(0.6),
                                ),
                                const SizedBox(height: 24),
                                
                                // Total Focus section — expands to fill all remaining space
                                Expanded(
                                  child: Builder(builder: (context) {
                                    final activeDay = _selectedDate ?? DateTime.now();
                                    final isToday = activeDay.year == DateTime.now().year &&
                                        activeDay.month == DateTime.now().month &&
                                        activeDay.day == DateTime.now().day;
                                    final secondsOnDay = _getSecondsForDay(activeDay);
                                    
                                    final daySessions = _sessions
                                        .where((s) =>
                                            s.startTime.year == activeDay.year &&
                                            s.startTime.month == activeDay.month &&
                                            s.startTime.day == activeDay.day)
                                        .toList();
                                    daySessions.sort((a, b) => a.startTime.compareTo(b.startTime));
                                    
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isToday
                                                      ? 'TOTAL FOCUS TODAY'
                                                      : 'FOCUS ON ${DateFormat('MMM d, yyyy').format(activeDay).toUpperCase()}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.0,
                                                    color: colors.foreground.withOpacity(0.5),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _formatSessionDurationFriendly(secondsOnDay),
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: colors.foreground,
                                                    letterSpacing: -1.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (!isToday)
                                              TextButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedDate = DateTime.now();
                                                  });
                                                },
                                                icon: const Icon(Icons.today, size: 14),
                                                label: const Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: AppColors.focusAccent,
                                                  backgroundColor: colors.background,
                                                  side: BorderSide(color: colors.border),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                                                  ),
                                                ),
                                              ),
                                            if (daySessions.isNotEmpty)
                                              Tooltip(
                                                message: 'Clear ${isToday ? "today\'s" : DateFormat('MMM d').format(activeDay)} records',
                                                child: IconButton(
                                                  onPressed: () => _clearDayRecords(activeDay),
                                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                                  color: colors.foreground.withOpacity(0.4),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  style: IconButton.styleFrom(
                                                    hoverColor: Colors.redAccent.withOpacity(0.1),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        if (daySessions.isEmpty)
                                          Expanded(
                                            child: Container(
                                              width: double.infinity,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: colors.background.withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                                                border: Border.all(
                                                  color: colors.border.withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                'No focus sessions recorded',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: colors.foreground.withOpacity(0.4),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Expanded(
                                            child: ScrollConfiguration(
                                              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                                              child: SingleChildScrollView(
                                                physics: const BouncingScrollPhysics(),
                                                child: Column(
                                                  children: daySessions.asMap().entries.map((entry) {
                                                    final lapIndex = entry.key + 1;
                                                    final session = entry.value;
                                                    final durationStr = _formatSessionDurationFriendly(session.durationSeconds);
                                                    
                                                    return Container(
                                                      margin: const EdgeInsets.only(bottom: 8),
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: colors.background.withOpacity(0.5),
                                                        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                                                        border: Border.all(
                                                          color: colors.border.withOpacity(0.3),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(
                                                                Icons.adjust_rounded,
                                                                size: 14,
                                                                color: AppColors.focusAccent.withOpacity(0.7),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                'Lap $lapIndex',
                                                                style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight: FontWeight.w500,
                                                                  color: colors.foreground,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          Text(
                                                            durationStr,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.bold,
                                                              color: AppColors.focusAccent,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                ),
                                
                                // Divider styled carefully as a light gray / dark border line
                                const SizedBox(height: 16),
                                Container(
                                  height: 1,
                                  color: colors.border.withOpacity(0.6),
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showExportDialog,
                                        icon: const Icon(Icons.download_rounded, size: 16),
                                        label: const Text('Export'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: colors.foreground,
                                          side: BorderSide(color: colors.border),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showImportDialog,
                                        icon: const Icon(Icons.upload_rounded, size: 16),
                                        label: const Text('Import'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: colors.foreground,
                                          side: BorderSide(color: colors.border),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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


  // Small legend box builder
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

  // Get total study seconds for a specific calendar date (including active timer today)
  int _getSecondsForDay(DateTime day) {
    int total = _sessions
        .where((s) =>
            s.startTime.year == day.year &&
            s.startTime.month == day.month &&
            s.startTime.day == day.day)
        .fold<int>(0, (sum, s) => sum + s.durationSeconds);
        
    final now = DateTime.now();
    if (_isTimerActive &&
        day.year == now.year &&
        day.month == now.month &&
        day.day == now.day) {
      total += _secondsElapsed;
    }
    return total;
  }

  // Monthly activity heat map grid builder with interactive day selection and navigation
  Widget _buildActivityHeatMap(AppColors colors) {
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    
    final firstDay = DateTime(year, month, 1);
    final weekdayOffset = firstDay.weekday - 1; // 0 for Mon, 6 for Sun
    final totalDays = DateTime(year, month + 1, 0).day;
    
    final List<DateTime?> cells = [];
    for (int i = 0; i < weekdayOffset; i++) {
      cells.add(null);
    }
    for (int i = 1; i <= totalDays; i++) {
      cells.add(DateTime(year, month, i));
    }
    final remaining = (7 - (cells.length % 7)) % 7;
    for (int i = 0; i < remaining; i++) {
      cells.add(null);
    }
    
    final List<List<DateTime?>> weeks = [];
    for (int i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, i + 7));
    }
    
    final now = DateTime.now();
    final List<String> daysLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    return Column(
      children: [
        // Month navigator header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_calendarMonth),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: colors.foreground,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(foregroundColor: colors.foreground),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(foregroundColor: colors.foreground),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Days of week header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: daysLabels.map((lbl) => Expanded(
            child: Text(
              lbl,
              textAlign: TextAlign.center,
              style: AppDesign.getBodyMutedStyle(colors).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          )).toList(),
        ),
        const SizedBox(height: 6),
        
        // Month weeks grid
        Column(
          children: weeks.map((week) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: week.map((dayDate) {
                  if (dayDate == null) {
                    return const Expanded(
                      child: SizedBox(height: 28),
                    );
                  }
                  
                  final secondsStudied = _getSecondsForDay(dayDate);
                  final isToday = dayDate.year == now.year &&
                      dayDate.month == now.month &&
                      dayDate.day == now.day;
                  
                  final activeDay = _selectedDate ?? now;
                  final isSelected = dayDate.year == activeDay.year &&
                      dayDate.month == activeDay.month &&
                      dayDate.day == activeDay.day;
                  
                  return Expanded(
                    child: Tooltip(
                      message: '${DateFormat('MMM d, yyyy').format(dayDate)}: ${_formatSessionDurationFriendly(secondsStudied)}',
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = dayDate;
                          });
                        },
                        child: Container(
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 2.0),
                          decoration: BoxDecoration(
                            color: _getHeatMapColor(secondsStudied, colors),
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(color: colors.primary, width: 2)
                                : (isToday
                                    ? Border.all(color: colors.ring, width: 1)
                                    : null),
                          ),
                          child: Center(
                            child: Text(
                              '${dayDate.day}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                                color: secondsStudied > 0
                                    ? (secondsStudied > 1800 ? Colors.white : colors.foreground)
                                    : colors.foreground.withOpacity(0.6),
                              ),
                            ),
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

  // Shading logic
  Color _getHeatMapColor(int seconds, AppColors colors) {
    if (seconds <= 0) {
      return colors.background;
    }
    final Color baseAccent = AppColors.focusAccent;
    final int minutes = seconds ~/ 60;
    if (minutes < 15) {
      return baseAccent.withOpacity(0.30);
    } else if (minutes < 45) {
      return baseAccent.withOpacity(0.65);
    } else {
      return baseAccent;
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
          // Title
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/logo_s.png',
                        height: 22,
                        width: 22,
                      ),
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
            tooltip: 'Toggle Theme',
            onPressed: onThemeToggle,
            splashRadius: 18,
          ),

          // Custom Window controls
          if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) ...[
            Container(
              width: 1,
              height: 20,
              color: colors.border,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            IconButton(
              icon: Icon(Icons.remove, size: 14, color: colors.foreground),
              onPressed: () async {
                await windowManager.minimize();
              },
              splashRadius: 18,
              tooltip: 'Minimize',
            ),
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
