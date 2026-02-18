import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A compact circular gauge that displays win probability.
///
/// Shows an animated arc whose fill and colour reflect the current win
/// probability. Designed to fit in the corner of the game screen at 64x64.
class WinProbabilityGauge extends StatelessWidget {
  final double winProbability;
  final bool isLoading;

  /// Size of the widget (width and height). Defaults to 64.
  final double size;

  const WinProbabilityGauge({
    super.key,
    required this.winProbability,
    this.isLoading = false,
    this.size = 64,
  });

  Color _gaugeColor(double probability) {
    if (probability > 0.60) return AppColors.success;
    if (probability > 0.30) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _gaugeColor(winProbability);
    final percentage = (winProbability * 100).round();

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: winProbability),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, animatedValue, child) {
          return CustomPaint(
            painter: _GaugeArcPainter(
              progress: animatedValue,
              color: _gaugeColor(animatedValue),
              backgroundColor: AppColors.surfaceLight,
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                Text(
                  '...',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                Text(
                  '$percentage%',
                  style: TextStyle(
                    color: color,
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              Text(
                'Win',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws the circular gauge arc.
class _GaugeArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _GaugeArcPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4;
    const strokeWidth = 5.0;
    const startAngle = -math.pi / 2; // Start from top (12 o'clock)
    const fullSweep = 2 * math.pi;

    // Background arc (full circle).
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep,
      false,
      bgPaint,
    );

    // Progress arc.
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fullSweep * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugeArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
