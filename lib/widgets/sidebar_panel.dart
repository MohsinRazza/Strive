import 'package:flutter/material.dart';

import '../design_system.dart';
import '../session_model.dart';
import 'activity_heatmap.dart';
import 'lap_list.dart';

/// Right sidebar: heatmap + legend + daily performance (lap list) + data management buttons.
class SidebarPanel extends StatelessWidget {
  final AppColors colors;
  final bool isTimerActive;
  final bool showLaps;
  final VoidCallback onLapsToggle;
  final List<StudySession> sessions;
  final DateTime calendarMonth;
  final DateTime? selectedDate;
  final int Function(DateTime) getSecondsForDay;
  final String Function(int) formatDurationFriendly;
  final void Function(DateTime) onDaySelected;
  final void Function(DateTime) onMonthChanged;
  final void Function(DateTime) onClearDay;
  final VoidCallback onGoToToday;
  final VoidCallback onExport;
  final VoidCallback onImport;

  const SidebarPanel({
    super.key,
    required this.colors,
    required this.isTimerActive,
    required this.showLaps,
    required this.onLapsToggle,
    required this.sessions,
    required this.calendarMonth,
    required this.selectedDate,
    required this.getSecondsForDay,
    required this.formatDurationFriendly,
    required this.onDaySelected,
    required this.onMonthChanged,
    required this.onClearDay,
    required this.onGoToToday,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final activeDay = selectedDate ?? DateTime.now();
    final daySessions = sessions
        .where((s) =>
            s.startTime.year == activeDay.year &&
            s.startTime.month == activeDay.month &&
            s.startTime.day == activeDay.day)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final secondsOnDay = getSecondsForDay(activeDay);

    return AnimatedContainer(
      duration: AppDesign.transitionDuration,
      curve: AppDesign.transitionCurve,
      width: isTimerActive ? 0 : 400,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          left: BorderSide(
            color: isTimerActive ? Colors.transparent : colors.border,
            width: 1,
          ),
        ),
      ),
      child: OverflowBox(
        minWidth: 400,
        maxWidth: 400,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heatmap
                ActivityHeatmap(
                  colors: colors,
                  calendarMonth: calendarMonth,
                  sessions: sessions,
                  selectedDate: selectedDate,
                  onDaySelected: onDaySelected,
                  onMonthChanged: onMonthChanged,
                  getSecondsForDay: getSecondsForDay,
                  formatDurationFriendly: formatDurationFriendly,
                ),

                // Legend
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Less', style: AppDesign.getBodyMutedStyle(colors).copyWith(fontSize: 10)),
                    const SizedBox(width: 4),
                    HeatmapLegendBox(color: colors.border),
                    const SizedBox(width: 3),
                    HeatmapLegendBox(color: colors.focusAccent.withOpacity(0.3)),
                    const SizedBox(width: 3),
                    HeatmapLegendBox(color: colors.focusAccent.withOpacity(0.65)),
                    const SizedBox(width: 3),
                    HeatmapLegendBox(color: colors.focusAccent),
                    const SizedBox(width: 4),
                    Text('More', style: AppDesign.getBodyMutedStyle(colors).copyWith(fontSize: 10)),
                  ],
                ),

                const SizedBox(height: 24),
                Container(height: 1, color: colors.border.withOpacity(0.6)),
                const SizedBox(height: 24),

                // Daily lap list (expands to fill remaining space)
                Expanded(
                  child: LapList(
                    colors: colors,
                    activeDay: activeDay,
                    daySessions: daySessions,
                    secondsOnDay: secondsOnDay,
                    showLaps: showLaps,
                    onLapsToggle: onLapsToggle,
                    formatDurationFriendly: formatDurationFriendly,
                    onGoToToday: onGoToToday,
                    onClearDay: () => onClearDay(activeDay),
                  ),
                ),

                // Data management footer
                const SizedBox(height: 16),
                Container(height: 1, color: colors.border.withOpacity(0.6)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onExport,
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Export'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.foreground,
                          side: BorderSide(color: colors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onImport,
                        icon: const Icon(Icons.upload_rounded, size: 16),
                        label: const Text('Import'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.foreground,
                          side: BorderSide(color: colors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput)),
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
    );
  }
}
