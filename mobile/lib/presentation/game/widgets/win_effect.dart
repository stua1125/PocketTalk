import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

/// Victory celebration effect displayed when a player wins a hand.
///
/// Renders three layered effects around / over the winning player's seat:
///   1. A gold shimmer / glow ring around the seat.
///   2. An animated chip-count that counts up from 0 to [winAmount].
///   3. A confetti-like particle burst drawn with [CustomPainter].
///
/// The effect auto-dismisses after [duration] (default 2 seconds) and calls
/// [onComplete].
///
/// Place this inside the same [Stack] as the poker table, positioned over
/// the winning player's seat.
class WinEffect extends StatefulWidget {
  /// The amount of chips won (displayed as a counting-up number).
  final int winAmount;

  /// The size of the effect area. Should be large enough to encompass the
  /// player seat plus surrounding glow/particles.
  final double size;

  /// How long the entire celebration lasts.
  final Duration duration;

  /// Called when the effect finishes and should be removed from the tree.
  final VoidCallback? onComplete;

  const WinEffect({
    super.key,
    required this.winAmount,
    this.size = 160,
    this.duration = const Duration(seconds: 2),
    this.onComplete,
  });

  @override
  State<WinEffect> createState() => _WinEffectState();
}

class _WinEffectState extends State<WinEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;
  late final Animation<int> _countAnimation;
  late final Animation<double> _particleAnimation;
  late final Animation<double> _fadeOutAnimation;

  late final List<_Particle> _particles;

  static const int _particleCount = 20;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Glow: pulses twice over the full duration.
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);

    // Chip count ticks up over the first 60% of the animation.
    _countAnimation = IntTween(
      begin: 0,
      end: widget.winAmount,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    // Particle expansion: 0 -> 1 over the animation lifetime.
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Fade out over the final 30%.
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // Generate random particles.
    final rng = math.Random();
    _particles = List.generate(_particleCount, (_) {
      return _Particle(
        angle: rng.nextDouble() * 2 * math.pi,
        speed: 0.5 + rng.nextDouble() * 0.5, // 0.5..1.0
        size: 3.0 + rng.nextDouble() * 5.0,
        color: _randomGoldColor(rng),
        isStar: rng.nextBool(),
      );
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    _controller.forward();
  }

  Color _randomGoldColor(math.Random rng) {
    const colors = [
      AppColors.chipGold,
      Color(0xFFFFC107), // amber
      Color(0xFFFFAB00), // amber accent
      Color(0xFFFFD54F), // lighter gold
      Colors.white,
    ];
    return colors[rng.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final fadeOut = _fadeOutAnimation.value;

          return Opacity(
            opacity: fadeOut,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Gold glow ring
                _buildGlow(),

                // 2. Confetti particles -- wrapped in RepaintBoundary so the
                // custom-painted particles don't cause the glow / text layers
                // to repaint.
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _particleAnimation.value,
                      maxRadius: widget.size / 2,
                    ),
                  ),
                ),

                // 3. Chip count text
                _buildCountText(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlow() {
    final glowIntensity = _glowAnimation.value;

    return Container(
      width: widget.size * 0.6,
      height: widget.size * 0.6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.chipGold.withOpacity(0.5 * glowIntensity),
            blurRadius: 24 * glowIntensity,
            spreadRadius: 8 * glowIntensity,
          ),
          BoxShadow(
            color: const Color(0xFFFFAB00).withOpacity(0.3 * glowIntensity),
            blurRadius: 40 * glowIntensity,
            spreadRadius: 16 * glowIntensity,
          ),
        ],
      ),
    );
  }

  Widget _buildCountText() {
    final count = _countAnimation.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+${_formatAmount(count)}',
          style: AppTypography.chipAmount.copyWith(
            color: AppColors.chipGold,
            fontSize: 22,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'WINNER',
          style: TextStyle(
            color: AppColors.chipGold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Particle system
// ---------------------------------------------------------------------------

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final bool isStar;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.isStar,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0..1
  final double maxRadius;

  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final distance = maxRadius * progress * p.speed;
      final dx = center.dx + math.cos(p.angle) * distance;
      final dy = center.dy + math.sin(p.angle) * distance;

      // Particles fade out as they travel.
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(opacity);

      if (p.isStar) {
        _drawStar(canvas, Offset(dx, dy), p.size, paint);
      } else {
        canvas.drawCircle(Offset(dx, dy), p.size * (1.0 - progress * 0.5), paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 4;
    const innerRatio = 0.4;

    for (int i = 0; i < points * 2; i++) {
      final angle = (math.pi / points) * i - math.pi / 2;
      final r = i.isEven ? radius : radius * innerRatio;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    // Only repaint when progress actually changes; particle list and
    // maxRadius are stable for the lifetime of this effect.
    return oldDelegate.progress != progress;
  }
}
