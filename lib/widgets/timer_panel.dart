import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design_system.dart';

/// Left panel: large timer clock + start/pause/resume/stop controls.
/// Shows an animated pulsing ring background when a session is active.
class TimerPanel extends StatefulWidget {
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
  State<TimerPanel> createState() => _TimerPanelState();
}

class _TimerPanelState extends State<TimerPanel> with TickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    // Radial glow breathes in/out over 3 seconds
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isTimerActive && !widget.isTimerPaused;

    return Stack(
      children: [
        // ── Pulse glow (only during active focus) ───────────────
        Positioned.fill(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            opacity: isActive ? 1.0 : 0.0,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FocusGlowPainter(
                    intensity: _glowController.value,
                    color: widget.colors.focusAccent,
                  ),
                );
              },
            ),
          ),
        ),

        // ── Timer content ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.formatSeconds(widget.secondsElapsed),
                  style: AppDesign.getTimerStyle(widget.colors).copyWith(fontSize: 96),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.isTimerActive
                    ? (widget.isTimerPaused ? 'SESSION PAUSED' : 'FOCUS IN PROGRESS')
                    : 'READY TO FOCUS',
                style: AppDesign.getWidgetHeaderStyle(widget.colors).copyWith(
                  letterSpacing: 2.0,
                  color: isActive ? widget.colors.focusAccent : widget.colors.muted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!widget.isTimerActive) ...[
                    _StartButton(colors: widget.colors, onStart: widget.onStart),
                  ] else ...[
                    _PauseResumeButton(
                      colors: widget.colors,
                      isPaused: widget.isTimerPaused,
                      onPause: widget.onPause,
                      onResume: widget.onResume,
                    ),
                    const SizedBox(width: 16),
                    _StopButton(colors: widget.colors, onStop: widget.onStop),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter: breathing radial glow only
// ─────────────────────────────────────────────────────────────────────────────
class _FocusGlowPainter extends CustomPainter {
  final double intensity; // 0.0 → 1.0, breathes
  final Color color;

  const _FocusGlowPainter({
    required this.intensity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.65;
    // Ease the intensity for a smoother breath curve
    final eased = Curves.easeInOut.transform(intensity);
    final opacity = (0.05 + eased * 0.10).clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), color.withOpacity(0.0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, paint);
  }

  @override
  bool shouldRepaint(_FocusGlowPainter old) => old.intensity != intensity;
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────

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
  const _PauseResumeButton(
      {required this.colors,
      required this.isPaused,
      required this.onPause,
      required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.foreground.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isPaused ? onResume : onPause,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.card,
          foregroundColor: colors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.border.withOpacity(0.8), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 22, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              isPaused ? 'Resume Focus' : 'Pause Timer',
              style: AppDesign.getLogFeedStyle(colors).copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.softRedText.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onStop,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.softRedBg,
          foregroundColor: colors.softRedText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.softRedBorder.withOpacity(0.5), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_rounded, size: 22, color: colors.softRedText),
            const SizedBox(width: 8),
            Text(
              'Stop & Save',
              style: AppDesign.getLogFeedStyle(colors).copyWith(
                color: colors.softRedText,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
