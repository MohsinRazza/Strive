import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system.dart';
import '../session_model.dart';

/// Monthly activity heatmap grid with interactive day selection and month navigation.
class ActivityHeatmap extends StatelessWidget {
  final AppColors colors;
  final DateTime calendarMonth;
  final List<StudySession> sessions;
  final DateTime? selectedDate;
  final void Function(DateTime) onDaySelected;
  final void Function(DateTime) onMonthChanged;
  final int Function(DateTime) getSecondsForDay;
  final String Function(int) formatDurationFriendly;

  const ActivityHeatmap({
    super.key,
    required this.colors,
    required this.calendarMonth,
    required this.sessions,
    required this.selectedDate,
    required this.onDaySelected,
    required this.onMonthChanged,
    required this.getSecondsForDay,
    required this.formatDurationFriendly,
  });

  @override
  Widget build(BuildContext context) {
    final year = calendarMonth.year;
    final month = calendarMonth.month;
    final firstDay = DateTime(year, month, 1);
    final weekdayOffset = firstDay.weekday - 1;
    final totalDays = DateTime(year, month + 1, 0).day;

    final List<DateTime?> cells = [
      for (int i = 0; i < weekdayOffset; i++) null,
      for (int i = 1; i <= totalDays; i++) DateTime(year, month, i),
    ];
    final remaining = (7 - (cells.length % 7)) % 7;
    for (int i = 0; i < remaining; i++) cells.add(null);

    final List<List<DateTime?>> weeks = [
      for (int i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7),
    ];

    final now = DateTime.now();
    const daysLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Month navigator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(calendarMonth),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: colors.foreground),
            ),
            Container(
              decoration: BoxDecoration(
                color: colors.background,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Previous month',
                    child: InkWell(
                      onTap: () => onMonthChanged(DateTime(calendarMonth.year, calendarMonth.month - 1)),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                      hoverColor: colors.foreground.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: colors.foreground.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 16, color: colors.border),
                  Tooltip(
                    message: 'Next month',
                    child: InkWell(
                      onTap: () => onMonthChanged(DateTime(calendarMonth.year, calendarMonth.month + 1)),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                      hoverColor: colors.foreground.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: colors.foreground.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Day of week labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: daysLabels
              .map((lbl) => Expanded(
                    child: Text(lbl, textAlign: TextAlign.center,
                        style: AppDesign.getBodyMutedStyle(colors).copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                  ))
              .toList(),
        ),
        const SizedBox(height: 6),
        // Weeks grid
        Column(
          children: weeks.map((week) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: week.map((dayDate) {
                  if (dayDate == null) {
                    return const Expanded(child: SizedBox(height: 28));
                  }
                  final secondsStudied = getSecondsForDay(dayDate);
                  final isToday = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
                  final activeDay = selectedDate ?? now;
                  final isSelected = dayDate.year == activeDay.year && dayDate.month == activeDay.month && dayDate.day == activeDay.day;

                  return Expanded(
                    child: Tooltip(
                      message: '${DateFormat('MMM d, yyyy').format(dayDate)}: ${formatDurationFriendly(secondsStudied)}',
                      child: GestureDetector(
                        onTap: () => onDaySelected(dayDate),
                        child: Container(
                          height: 28,
                          margin: const EdgeInsets.symmetric(horizontal: 2.0),
                          decoration: BoxDecoration(
                            color: _getHeatMapColor(secondsStudied, colors),
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(color: colors.primary, width: 2)
                                : (isToday ? Border.all(color: colors.ring, width: 1) : null),
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

  Color _getHeatMapColor(int seconds, AppColors colors) {
    if (seconds <= 0) return colors.background;
    final minutes = seconds ~/ 60;
    if (minutes == 0) return colors.border;
    if (minutes < 15) return colors.focusAccent.withOpacity(0.30);
    if (minutes < 45) return colors.focusAccent.withOpacity(0.65);
    return colors.focusAccent;
  }
}

/// Small legend box used below the heatmap.
class HeatmapLegendBox extends StatelessWidget {
  final Color color;
  const HeatmapLegendBox({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}
