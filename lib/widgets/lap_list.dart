import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system.dart';
import '../session_model.dart';

/// Daily lap list with header (total focus time), individual session rows,
/// a "back to today" button, and a clear-day trash button.
class LapList extends StatelessWidget {
  final AppColors colors;
  final DateTime activeDay;
  final List<StudySession> daySessions;
  final int secondsOnDay;
  final String Function(int) formatDurationFriendly;
  final VoidCallback onGoToToday;
  final VoidCallback onClearDay;

  const LapList({
    super.key,
    required this.colors,
    required this.activeDay,
    required this.daySessions,
    required this.secondsOnDay,
    required this.formatDurationFriendly,
    required this.onGoToToday,
    required this.onClearDay,
  });

  bool get _isToday {
    final now = DateTime.now();
    return activeDay.year == now.year && activeDay.month == now.month && activeDay.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isToday
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
                  formatDurationFriendly(secondsOnDay),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                    letterSpacing: -1.0,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (!_isToday)
                  TextButton.icon(
                    onPressed: onGoToToday,
                    icon: const Icon(Icons.today, size: 14),
                    label: const Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.focusAccent,
                      backgroundColor: colors.background,
                      side: BorderSide(color: colors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput)),
                    ),
                  ),
                if (daySessions.isNotEmpty)
                  Tooltip(
                    message: 'Clear ${_isToday ? "today\'s" : DateFormat('MMM d').format(activeDay)} records',
                    child: IconButton(
                      onPressed: onClearDay,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: colors.foreground.withOpacity(0.4),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(hoverColor: Colors.redAccent.withOpacity(0.1)),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Lap rows or empty state
        if (daySessions.isEmpty)
          Expanded(child: _EmptyState(colors: colors))
        else
          Expanded(child: _LapRows(colors: colors, sessions: daySessions, formatDuration: formatDurationFriendly)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppColors colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
        border: Border.all(color: colors.border.withOpacity(0.3), width: 1),
      ),
      child: Text(
        'No focus sessions recorded',
        style: TextStyle(fontSize: 13, color: colors.foreground.withOpacity(0.4), fontStyle: FontStyle.italic),
      ),
    );
  }
}

class _LapRows extends StatelessWidget {
  final AppColors colors;
  final List<StudySession> sessions;
  final String Function(int) formatDuration;
  const _LapRows({required this.colors, required this.sessions, required this.formatDuration});

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: sessions.asMap().entries.map((entry) {
            final lapIndex = entry.key + 1;
            final session = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
                border: Border.all(color: colors.border.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.adjust_rounded, size: 14, color: AppColors.focusAccent.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text('Lap $lapIndex', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.foreground)),
                    ],
                  ),
                  Text(
                    formatDuration(session.durationSeconds),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.focusAccent),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
