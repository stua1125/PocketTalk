import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Color mapping for each poker hand rank.
///
/// Ordered from strongest (Royal Flush) to weakest (High Card) to maintain
/// a consistent, visually distinct palette in the stacked bar.
const Map<String, Color> _handRankColors = {
  'ROYAL_FLUSH': AppColors.chipGold,
  'STRAIGHT_FLUSH': Color(0xFF9C27B0), // purple
  'FOUR_OF_A_KIND': Color(0xFFE91E63), // pink
  'FULL_HOUSE': Color(0xFF3F51B5), // indigo
  'FLUSH': Color(0xFF2196F3), // blue
  'STRAIGHT': Color(0xFF00BCD4), // cyan
  'THREE_OF_A_KIND': Color(0xFF4CAF50), // green
  'TWO_PAIR': Color(0xFFFF9800), // orange
  'ONE_PAIR': Color(0xFFFF5722), // deep orange
  'HIGH_CARD': Color(0xFF795548), // brown
};

/// Pretty display names for hand ranks.
const Map<String, String> _handRankLabels = {
  'ROYAL_FLUSH': 'Royal Flush',
  'STRAIGHT_FLUSH': 'Str. Flush',
  'FOUR_OF_A_KIND': 'Four of a Kind',
  'FULL_HOUSE': 'Full House',
  'FLUSH': 'Flush',
  'STRAIGHT': 'Straight',
  'THREE_OF_A_KIND': 'Three of a Kind',
  'TWO_PAIR': 'Two Pair',
  'ONE_PAIR': 'One Pair',
  'HIGH_CARD': 'High Card',
};

/// A compact horizontal stacked bar showing hand rank probabilities.
///
/// Each segment is colour-coded by hand rank. Tapping the bar shows a tooltip
/// with the full distribution. Labels for the top 3 most probable ranks are
/// displayed below the bar.
class HandStrengthBar extends StatelessWidget {
  /// Map of hand rank key (e.g. "FLUSH") to probability (0.0 - 1.0).
  final Map<String, double> handDistribution;

  /// Total width of the bar.
  final double width;

  /// Height of the coloured bar.
  final double barHeight;

  const HandStrengthBar({
    super.key,
    required this.handDistribution,
    this.width = 160,
    this.barHeight = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (handDistribution.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort entries by probability descending.
    final sorted = handDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Filter out zero-probability entries.
    final nonZero = sorted.where((e) => e.value > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    // Top 3 for labels.
    final top3 = nonZero.take(3).toList();

    return GestureDetector(
      onTap: () => _showDistributionDialog(context, nonZero),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(barHeight / 2),
              child: SizedBox(
                height: barHeight,
                width: width,
                child: Row(
                  children: nonZero.map((entry) {
                    final fraction = entry.value.clamp(0.0, 1.0);
                    return Expanded(
                      flex: (fraction * 1000).round().clamp(1, 1000),
                      child: Container(
                        color: _handRankColors[entry.key] ??
                            AppColors.surfaceLight,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Top 3 labels
            Row(
              children: top3.map((entry) {
                final pct = (entry.value * 100).round();
                final label = _handRankLabels[entry.key] ?? entry.key;
                final color =
                    _handRankColors[entry.key] ?? AppColors.textSecondary;
                return Expanded(
                  child: Text(
                    '$label $pct%',
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showDistributionDialog(
    BuildContext context,
    List<MapEntry<String, double>> entries,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Hand Distribution',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: entries.map((entry) {
              final pct = (entry.value * 100).toStringAsFixed(1);
              final label = _handRankLabels[entry.key] ?? entry.key;
              final color =
                  _handRankColors[entry.key] ?? AppColors.textSecondary;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.chipGold)),
          ),
        ],
      ),
    );
  }
}
