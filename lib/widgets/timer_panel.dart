import 'package:flutter/material.dart';
import '../design_system.dart';

/// Left panel: large timer clock + start/pause/resume/stop controls.
class TimerPanel extends StatelessWidget {
  final AppColors colors;
  final int secondsElapsed;
  final bool isTimerActive;
  final bool isTimerPaused;
  final String Function(int) formatSeconds;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const TimerPanel({
    super.key,
    required this.colors,
    required this.secondsElapsed,
    required this.isTimerActive,
    required this.isTimerPaused,
    required this.formatSeconds,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatSeconds(secondsElapsed),
            style: AppDesign.getTimerStyle(colors).copyWith(fontSize: 96),
          ),
          const SizedBox(height: 12),
          Text(
            isTimerActive
                ? (isTimerPaused ? 'SESSION PAUSED' : 'FOCUS IN PROGRESS')
                : 'READY TO FOCUS',
            style: AppDesign.getWidgetHeaderStyle(colors).copyWith(
              letterSpacing: 2.0,
              color: isTimerActive && !isTimerPaused
                  ? AppColors.focusAccent
                  : colors.muted,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isTimerActive) ...[
                _StartButton(colors: colors, onStart: onStart),
              ] else ...[
                _PauseResumeButton(
                  colors: colors,
                  isPaused: isTimerPaused,
                  onPause: onPause,
                  onResume: onResume,
                ),
                const SizedBox(width: 16),
                _StopButton(colors: colors, onStop: onStop),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onStart;
  const _StartButton({required this.colors, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onStart,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput)),
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
    );
  }
}

class _PauseResumeButton extends StatelessWidget {
  final AppColors colors;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  const _PauseResumeButton({required this.colors, required this.isPaused, required this.onPause, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isPaused ? onResume : onPause,
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
          Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            isPaused ? 'Resume' : 'Pause',
            style: AppDesign.getLogFeedStyle(colors).copyWith(color: colors.foreground, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final AppColors colors;
  final VoidCallback onStop;
  const _StopButton({required this.colors, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onStop,
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
            style: AppDesign.getLogFeedStyle(colors).copyWith(color: colors.softRedText, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
