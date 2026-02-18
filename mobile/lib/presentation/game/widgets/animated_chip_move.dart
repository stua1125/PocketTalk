import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

/// Animates a chip (with amount label) sliding from a player's position to
/// the pot in the center of the table.
///
/// The chip scales down slightly as it approaches the pot and the amount text
/// fades out over the course of the movement.
///
/// Both [playerPosition] and [potPosition] are in the coordinate space of the
/// enclosing [Stack].
///
/// Example:
/// ```dart
/// AnimatedChipMove(
///   amount: 200,
///   playerPosition: Offset(50, 300),
///   potPosition: Offset(200, 150),
///   onComplete: () {},
/// )
/// ```
class AnimatedChipMove extends StatefulWidget {
  /// The bet amount to display on the chip.
  final int amount;

  /// Where the chip starts (player's seat position).
  final Offset playerPosition;

  /// Where the chip ends (pot, center of the table).
  final Offset potPosition;

  /// Called when the animation finishes.
  final VoidCallback? onComplete;

  /// Duration of the slide animation.
  final Duration duration;

  /// Size of the chip circle.
  final double chipSize;

  const AnimatedChipMove({
    super.key,
    required this.amount,
    required this.playerPosition,
    required this.potPosition,
    this.onComplete,
    this.duration = const Duration(milliseconds: 400),
    this.chipSize = 32,
  });

  @override
  State<AnimatedChipMove> createState() => _AnimatedChipMoveState();
}

class _AnimatedChipMoveState extends State<AnimatedChipMove>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _positionAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Position: slide from player to pot.
    _positionAnimation = Tween<Offset>(
      begin: widget.playerPosition,
      end: widget.potPosition,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    // Scale: shrink to 70% as the chip nears the pot.
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    // Text opacity: fade out the amount label.
    _textOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      // Fade out in the second half of the animation.
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pos = _positionAnimation.value;
        final scale = _scaleAnimation.value;
        final textOpacity = _textOpacityAnimation.value;

        return Positioned(
          left: pos.dx - (widget.chipSize / 2) * scale,
          top: pos.dy - (widget.chipSize / 2) * scale,
          child: RepaintBoundary(
            child: Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chip circle
                  Container(
                    width: widget.chipSize,
                    height: widget.chipSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.chipGold, AppColors.chipRed],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '\$',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.chipSize * 0.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Amount label that fades out
                  Opacity(
                    opacity: textOpacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatAmount(widget.amount),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.chipGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Convenience widget that manages a list of chip-move animations occurring
/// at the same time (e.g., collecting all bets to the pot at end of round).
class AnimatedChipMoveGroup extends StatelessWidget {
  final List<ChipMoveData> chips;
  final Offset potPosition;
  final VoidCallback? onAllComplete;

  const AnimatedChipMoveGroup({
    super.key,
    required this.chips,
    required this.potPosition,
    this.onAllComplete,
  });

  @override
  Widget build(BuildContext context) {
    int completedCount = 0;

    return Stack(
      children: [
        for (final chip in chips)
          AnimatedChipMove(
            amount: chip.amount,
            playerPosition: chip.playerPosition,
            potPosition: potPosition,
            onComplete: () {
              completedCount++;
              if (completedCount >= chips.length) {
                onAllComplete?.call();
              }
            },
          ),
      ],
    );
  }
}

/// Describes a single chip-move: how much and from where.
class ChipMoveData {
  final int amount;
  final Offset playerPosition;

  const ChipMoveData({
    required this.amount,
    required this.playerPosition,
  });
}
