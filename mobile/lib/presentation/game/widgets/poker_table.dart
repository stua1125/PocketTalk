import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import 'player_seat.dart';
import 'community_cards.dart';
import 'pot_display.dart';
import '../../../domain/entities/card.dart';

class PokerTable extends StatelessWidget {
  final List<PlayerSeatData?> seats;
  final List<PokerCard> communityCards;
  final int potAmount;
  final int maxPlayers;

  const PokerTable({
    super.key,
    required this.seats,
    required this.communityCards,
    required this.potAmount,
    this.maxPlayers = 6,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          children: [
            // Table background (oval) -- wrapped in RepaintBoundary so the
            // static felt + border are not repainted when seats/cards change.
            Center(
              child: RepaintBoundary(
                child: Container(
                  width: width * 0.85,
                  height: height * 0.6,
                  decoration: BoxDecoration(
                    color: AppColors.tableFelt,
                    borderRadius: BorderRadius.circular(height * 0.3),
                    border: Border.all(color: AppColors.tableEdge, width: 8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Community cards (center) -- isolated so card reveal animations
            // don't repaint the table felt or player seats.
            Positioned(
              left: 0,
              right: 0,
              top: height * 0.35,
              child: RepaintBoundary(
                child: CommunityCards(cards: communityCards),
              ),
            ),

            // Pot display (above community cards)
            Positioned(
              left: 0,
              right: 0,
              top: height * 0.28,
              child: Center(child: PotDisplay(potAmount: potAmount)),
            ),

            // Player seats positioned around the table -- each seat gets its
            // own RepaintBoundary so avatar/chip updates on one seat don't
            // repaint the others.
            ..._buildSeatPositions(width, height),
          ],
        );
      },
    );
  }

  List<Widget> _buildSeatPositions(double width, double height) {
    final positions = _getSeatPositions(maxPlayers, width, height);
    final widgets = <Widget>[];

    for (int i = 0; i < maxPlayers; i++) {
      final pos = positions[i];
      final seatData = i < seats.length ? seats[i] : null;

      widgets.add(
        Positioned(
          left: pos.dx - 40,
          top: pos.dy - 45,
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seat number label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: seatData != null ? AppColors.primary : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${i + 1}',
                    style: TextStyle(
                      color: seatData != null ? Colors.white : Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                PlayerSeat(data: seatData, seatNumber: i),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Offset> _getSeatPositions(int count, double width, double height) {
    final centerX = width / 2;
    final centerY = height / 2;
    final radiusX = width * 0.42;
    final radiusY = height * 0.38;

    // Start from bottom center (my seat) and go clockwise
    const startAngle = math.pi / 2; // bottom
    final positions = <Offset>[];

    for (int i = 0; i < count; i++) {
      final angle = startAngle + (2 * math.pi * i / count);
      final x = centerX + radiusX * math.cos(angle);
      final y = centerY + radiusY * math.sin(angle);
      positions.add(Offset(x, y));
    }

    return positions;
  }
}
