import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Displays a brief, dramatic text overlay when the game transitions between
/// community-card stages: FLOP, TURN, RIVER, or SHOWDOWN.
///
/// The overlay scales in from 50% to 100% while fading in, holds briefly,
/// then fades out. Total visible duration is 1.5 seconds and it auto-dismisses.
///
/// Place inside the same [Stack] as the poker table, centered.
///
/// ```dart
/// StateTransitionOverlay(
///   state: 'FLOP',
///   onComplete: () { setState(() => _showOverlay = false); },
/// )
/// ```
class StateTransitionOverlay extends StatefulWidget {
  /// The game state label to display: "FLOP", "TURN", "RIVER", or "SHOWDOWN".
  final String state;

  /// Called when the animation completes and the overlay should be removed.
  final VoidCallback? onComplete;

  /// Total duration the overlay is visible (including fade in + hold + fade out).
  final Duration duration;

  const StateTransitionOverlay({
    super.key,
    required this.state,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<StateTransitionOverlay> createState() =>
      _StateTransitionOverlayState();
}

class _StateTransitionOverlayState extends State<StateTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Scale: 0.5 -> 1.0 in the first 30%, hold at 1.0, then stay.
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 70,
      ),
    ]).animate(_controller);

    // Opacity: fade-in (0->1) during 0%-20%, hold during 20%-70%, fade-out
    // (1->0) during 70%-100%.
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return IgnorePointer(
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: Center(
        child: Text(
          widget.state.toUpperCase(),
          style: TextStyle(
            color: AppColors.chipGold,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              Shadow(
                color: AppColors.chipGold.withOpacity(0.4),
                blurRadius: 16,
                offset: Offset.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
