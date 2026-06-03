import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design_system.dart';
import '../session_model.dart';
import '../session_storage.dart';

/// Shows a dialog when an interrupted session is found on startup.
/// Allows the user to save or discard the recovered session.
Future<void> showCrashRecoveryDialog({
  required BuildContext context,
  required AppColors colors,
  required StudySession session,
  required int elapsedSec,
  required Future<void> Function(StudySession) onSave,
}) async {
  final elapsedFormatted = _formatSeconds(elapsedSec);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
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
                  style: AppDesign.getLogFeedStyle(colors)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Started: ${DateFormat('MMM d, h:mm a').format(session.startTime)}',
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
            final completed = session.complete(DateTime.now());
            final finalCompleted = StudySession(
              id: completed.id,
              description: completed.description,
              startTime: completed.startTime,
              endTime: completed.endTime,
              durationSeconds: elapsedSec,
            );
            await onSave(finalCompleted);
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
    ),
  );
}

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
