import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/entities/card.dart';

class PokerCardWidget extends StatelessWidget {
  final PokerCard? card;
  final bool faceDown;
  final double width;
  final double height;

  const PokerCardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.width = 60,
    this.height = 84,
  });

  @override
  Widget build(BuildContext context) {
    if (faceDown || card == null) {
      return _buildCardBack();
    }
    return _buildCardFront(card!);
  }

  Widget _buildCardBack() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardBack,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      child: Center(
        child: Container(
          width: width * 0.7,
          height: height * 0.7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white30, width: 1),
          ),
          child: const Center(
            child: Text(
              'PT',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(PokerCard card) {
    final color = card.suit.isRed ? AppColors.cardRed : AppColors.cardBlack;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top-left rank + suit
            Text(
              card.rank.displayName,
              style: TextStyle(
                color: color,
                fontSize: width * 0.28,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            Text(
              card.suit.symbol,
              style: TextStyle(
                color: color,
                fontSize: width * 0.22,
                height: 1.0,
              ),
            ),
            // Center suit symbol
            Expanded(
              child: Center(
                child: Text(
                  card.suit.symbol,
                  style: TextStyle(
                    color: color,
                    fontSize: width * 0.45,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
