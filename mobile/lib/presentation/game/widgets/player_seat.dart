import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../common/avatar_widget.dart';
import '../../common/chip_display.dart';

enum PlayerStatus { active, folded, allIn, sittingOut, empty }

class PlayerSeatData {
  final String? id;
  final String nickname;
  final String? avatarUrl;
  final int chipCount;
  final int? currentBet;
  final PlayerStatus status;
  final bool isCurrentTurn;
  final bool isDealer;

  const PlayerSeatData({
    this.id,
    required this.nickname,
    this.avatarUrl,
    required this.chipCount,
    this.currentBet,
    this.status = PlayerStatus.active,
    this.isCurrentTurn = false,
    this.isDealer = false,
  });
}

class PlayerSeat extends StatefulWidget {
  final PlayerSeatData? data;
  final int seatNumber;

  /// Turn timer duration — must match the server-side auto-fold timeout.
  final Duration turnDuration;

  const PlayerSeat({
    super.key,
    this.data,
    required this.seatNumber,
    this.turnDuration = const Duration(seconds: 10),
  });

  @override
  State<PlayerSeat> createState() => _PlayerSeatState();
}

class _PlayerSeatState extends State<PlayerSeat>
    with TickerProviderStateMixin {
  AnimationController? _timerController;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant PlayerSeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasTurn = oldWidget.data?.isCurrentTurn ?? false;
    final isTurn = widget.data?.isCurrentTurn ?? false;

    if (isTurn && !wasTurn) {
      _startTimer();
    } else if (!isTurn && wasTurn) {
      _stopTimer();
    }
  }

  void _syncTimer() {
    if (widget.data?.isCurrentTurn == true) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timerController?.dispose();
    _timerController = AnimationController(
      vsync: this,
      duration: widget.turnDuration,
    );
    _timerController!.forward();
  }

  void _stopTimer() {
    _timerController?.stop();
    _timerController?.dispose();
    _timerController = null;
  }

  @override
  void dispose() {
    _timerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data == null || widget.data!.status == PlayerStatus.empty) {
      return _buildEmptySeat();
    }
    return _buildOccupiedSeat(widget.data!);
  }

  Widget _buildEmptySeat() {
    return Container(
      width: 80,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, style: BorderStyle.solid),
      ),
      child: const Center(
        child: Icon(Icons.add, color: Colors.white30, size: 24),
      ),
    );
  }

  Widget _buildOccupiedSeat(PlayerSeatData player) {
    final isFolded = player.status == PlayerStatus.folded;
    final isAllIn = player.status == PlayerStatus.allIn;

    return Opacity(
      opacity: isFolded ? 0.5 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with dealer button and timer ring
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Circular countdown ring behind the avatar
              if (player.isCurrentTurn && _timerController != null)
                _buildTimerRing(),
              // Avatar (slightly inset when timer ring is showing)
              Padding(
                padding: player.isCurrentTurn
                    ? const EdgeInsets.all(3)
                    : EdgeInsets.zero,
                child: AvatarWidget(
                  nickname: player.nickname,
                  imageUrl: player.avatarUrl,
                  size: 44,
                  isActive: !isFolded,
                  isCurrentTurn: player.isCurrentTurn,
                ),
              ),
              if (player.isDealer)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.chipGold,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'D',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Nickname
          Text(
            player.nickname,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          // Chips
          ChipDisplay(amount: player.chipCount, fontSize: 12, showIcon: false),
          // Status badge
          if (isAllIn)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.allIn,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ALL IN',
                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          if (isFolded)
            const Text(
              'FOLD',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 9),
            ),
        ],
      ),
    );
  }

  /// Circular arc that depletes clockwise as the turn timer progresses.
  Widget _buildTimerRing() {
    return AnimatedBuilder(
      animation: _timerController!,
      builder: (context, child) {
        final remaining = 1.0 - _timerController!.value;
        return CustomPaint(
          size: const Size(50, 50),
          painter: _TimerRingPainter(
            fraction: remaining,
            color: _timerColor(remaining),
          ),
        );
      },
    );
  }

  Color _timerColor(double fraction) {
    if (fraction > 0.5) return AppColors.success;
    if (fraction > 0.25) return AppColors.warning;
    return AppColors.error;
  }
}

/// Custom painter that draws an arc representing the remaining turn time.
class _TimerRingPainter extends CustomPainter {
  final double fraction;
  final Color color;

  _TimerRingPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at top
      2 * math.pi * fraction, // Sweep proportional to remaining time
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_TimerRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}
