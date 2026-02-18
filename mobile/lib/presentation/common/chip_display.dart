import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class ChipDisplay extends StatelessWidget {
  final int amount;
  final double fontSize;
  final bool showIcon;

  const ChipDisplay({
    super.key,
    required this.amount,
    this.fontSize = 16,
    this.showIcon = true,
  });

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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Container(
            width: fontSize * 1.2,
            height: fontSize * 1.2,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.chipGold, AppColors.chipGreen],
              ),
            ),
            child: Center(
              child: Text(
                '\$',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize * 0.6,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _formatAmount(amount),
          style: AppTypography.chipAmount.copyWith(
            fontSize: fontSize,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
