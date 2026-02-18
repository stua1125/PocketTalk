import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Displays a temporary label near a player's seat showing the action they
/// just took (FOLD, CHECK, CALL, RAISE, ALL IN).
///
/// The indicator slides in from the side, holds for a moment, then fades out.
/// Total visible duration is approximately 2 seconds.
///
/// ```dart
/// ActionIndicator(
///   action: PlayerAction.raise,
///   amount: 200,
///   slideDirection: SlideDirection.left,
///   onComplete: () { setState(() => _showIndicator = false); },
/// )
/// ```
class ActionIndicator extends StatefulWidget {
  /// The action the player performed.
  final PlayerAction action;

  /// Optional amount (for CALL and RAISE).
  final int? amount;

  /// Which direction the label slides in from.
  final SlideDirection slideDirection;

  /// Called when the animation finishes and the widget should be removed.
  final VoidCallback? onComplete;

  /// Total display duration.
  final Duration duration;

  const ActionIndicator({
    super.key,
    required this.action,
    this.amount,
    this.slideDirection = SlideDirection.left,
    this.onComplete,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<ActionIndicator> createState() => _ActionIndicatorState();
}

class _ActionIndicatorState extends State<ActionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Compute the starting offset based on slide direction.
    final beginOffset = switch (widget.slideDirection) {
      SlideDirection.left => const Offset(-1.5, 0.0),
      SlideDirection.right => const Offset(1.5, 0.0),
    };

    // Slide in during 0%-15%, hold, slide out is handled by opacity.
    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: beginOffset, end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween(Offset.zero),
        weight: 85,
      ),
    ]).animate(_controller);

    // Opacity: quick fade-in, hold, then fade-out in the last 25%.
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
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

  // ---------------------------------------------------------------------------
  // Styling helpers
  // ---------------------------------------------------------------------------

  String get _label {
    return switch (widget.action) {
      PlayerAction.fold => 'FOLD',
      PlayerAction.check => 'CHECK',
      PlayerAction.call =>
        widget.amount != null ? 'CALL \$${_formatAmount(widget.amount!)}' : 'CALL',
      PlayerAction.raise =>
        widget.amount != null ? 'RAISE \$${_formatAmount(widget.amount!)}' : 'RAISE',
      PlayerAction.allIn => 'ALL IN',
    };
  }

  Color get _backgroundColor {
    return switch (widget.action) {
      PlayerAction.fold => AppColors.fold,
      PlayerAction.check => AppColors.check,
      PlayerAction.call => AppColors.check,
      PlayerAction.raise => AppColors.chipGold,
      PlayerAction.allIn => AppColors.allIn,
    };
  }

  Color get _textColor {
    return switch (widget.action) {
      PlayerAction.raise => Colors.black,
      _ => Colors.white,
    };
  }

  FontWeight get _fontWeight {
    return switch (widget.action) {
      PlayerAction.allIn => FontWeight.w900,
      PlayerAction.raise => FontWeight.w800,
      _ => FontWeight.bold,
    };
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toString();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: _textColor,
            fontSize: 12,
            fontWeight: _fontWeight,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting types
// ---------------------------------------------------------------------------

/// The poker actions that can be indicated.
enum PlayerAction { fold, check, call, raise, allIn }

/// Direction from which the action indicator slides in.
enum SlideDirection { left, right }
