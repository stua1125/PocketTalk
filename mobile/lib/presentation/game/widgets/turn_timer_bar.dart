import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// A horizontal countdown bar that displays above the action panel when it is
/// the local player's turn. Counts down from [duration] to 0.
///
/// The bar animates smoothly from full to empty. The colour shifts from green
/// through yellow to red as time runs out.
class TurnTimerBar extends StatefulWidget {
  /// Total turn duration.
  final Duration duration;

  /// Called when the countdown reaches zero.
  final VoidCallback? onTimeout;

  /// An opaque key that, when changed, restarts the timer. Typically pass
  /// the current hand's `currentPlayerId` or a concatenation of hand-id +
  /// state so the bar resets whenever a new turn begins.
  final String? resetKey;

  const TurnTimerBar({
    super.key,
    this.duration = const Duration(seconds: 10),
    this.onTimeout,
    this.resetKey,
  });

  @override
  State<TurnTimerBar> createState() => TurnTimerBarState();
}

class TurnTimerBarState extends State<TurnTimerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant TurnTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != oldWidget.resetKey) {
      _controller.reset();
      _controller.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onTimeout?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The remaining fraction (1.0 → 0.0).
  double get remaining => 1.0 - _controller.value;

  Color _barColor(double fraction) {
    if (fraction > 0.5) return AppColors.success;
    if (fraction > 0.25) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final frac = remaining;
        final seconds = (frac * widget.duration.inSeconds).ceil();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.surface,
          ),
          child: Row(
            children: [
              // Seconds label
              SizedBox(
                width: 28,
                child: Text(
                  '${seconds}s',
                  style: TextStyle(
                    color: _barColor(frac),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Progress bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: frac,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(_barColor(frac)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
