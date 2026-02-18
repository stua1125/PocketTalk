import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../common/chip_display.dart';

class PotDisplay extends StatelessWidget {
  final int potAmount;

  const PotDisplay({super.key, required this.potAmount});

  @override
  Widget build(BuildContext context) {
    if (potAmount <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Pot: ',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          ChipDisplay(amount: potAmount, fontSize: 15),
        ],
      ),
    );
  }
}
