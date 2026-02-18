import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../domain/entities/card.dart';
import '../../common/poker_card_widget.dart';

class CommunityCards extends StatelessWidget {
  final List<PokerCard> cards;

  const CommunityCards({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        if (index < cards.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs / 2),
            child: PokerCardWidget(card: cards[index], width: 50, height: 70),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs / 2),
            child: Container(
              width: 50,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
            ),
          );
        }
      }),
    );
  }
}
