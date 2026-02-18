import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// An individual floating emoji reaction that animates and then self-removes.
///
/// Animation sequence (total duration: 3 seconds):
///   0.0 - 0.3 : scale from 0.0 to 1.2  (bounce in)
///   0.3 - 0.5 : scale from 1.2 to 1.0  (settle)
///   0.0 - 1.0 : float upward by ~80 px
///   0.7 - 1.0 : fade out (opacity 1.0 -> 0.0)
///
/// Calls [onComplete] after the animation finishes so the parent overlay can
/// dispose of this widget and release resources.
class FloatingEmoji extends StatefulWidget {
  final String emoji;
  final String senderName;
  final Offset startPosition;
  final VoidCallback onComplete;

  const FloatingEmoji({
    super.key,
    required this.emoji,
    required this.senderName,
    required this.startPosition,
    required this.onComplete,
  });

  @override
  State<FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // -- Scale --
  late final Animation<double> _scaleIn;
  late final Animation<double> _scaleSettle;

  // -- Vertical offset (float upward) --
  late final Animation<double> _translateY;

  // -- Opacity (fade out) --
  late final Animation<double> _opacity;

  static const _totalDuration = Duration(seconds: 3);
  static const _floatDistance = 80.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: _totalDuration);

    // 0.0 -> 0.3 : scale 0 -> 1.2
    _scaleIn = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // 0.3 -> 0.5 : scale 1.2 -> 1.0
    _scaleSettle = Tween<double>(begin: 1.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.5, curve: Curves.easeInOut),
      ),
    );

    // 0.0 -> 1.0 : float upward
    _translateY = Tween<double>(begin: 0.0, end: -_floatDistance).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    // 0.7 -> 1.0 : fade out
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Resolve the current scale value from the two sequential scale tweens.
  double _currentScale() {
    if (_controller.value <= 0.3) {
      return _scaleIn.value;
    }
    return _scaleSettle.value;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.startPosition.dx - 28, // centre the 56 px wide emoji column
      top: widget.startPosition.dy - 60, // above the player seat
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _translateY.value),
              child: Opacity(
                opacity: _opacity.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: _currentScale(),
                  child: child,
                ),
              ),
            );
          },
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.emoji,
            style: const TextStyle(fontSize: 36),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            widget.senderName,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 4),
              ],
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
