import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';

/// A bottom-sheet-style slider for choosing a raise amount.
///
/// Shows a horizontal slider, a live value display, quick-bet buttons
/// (1/2 pot, 3/4 pot, pot, all-in), and Confirm / Cancel actions.
class BetSlider extends StatefulWidget {
  /// Minimum raise amount (e.g. 2x big blind or min-raise).
  final int minBet;

  /// Maximum bet the player can make (their chip count).
  final int maxBet;

  /// The current highest bet on the table (used for pot-relative shortcuts).
  final int currentBet;

  /// Current pot amount (used for pot-relative shortcuts).
  final int potAmount;

  /// Called when the user taps Confirm with the chosen amount.
  final ValueChanged<int> onConfirm;

  /// Called when the user cancels the raise.
  final VoidCallback onCancel;

  const BetSlider({
    super.key,
    required this.minBet,
    required this.maxBet,
    required this.currentBet,
    this.potAmount = 0,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<BetSlider> createState() => _BetSliderState();
}

class _BetSliderState extends State<BetSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.minBet.toDouble();
  }

  @override
  void didUpdateWidget(covariant BetSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.minBet != oldWidget.minBet) {
      _value = _value.clamp(widget.minBet.toDouble(), widget.maxBet.toDouble());
    }
  }

  void _setPreset(double amount) {
    setState(() {
      _value = amount.clamp(widget.minBet.toDouble(), widget.maxBet.toDouble());
    });
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure the slider has a valid range.
    final effectiveMin = widget.minBet.toDouble();
    final effectiveMax = widget.maxBet.toDouble().clamp(effectiveMin, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ------- Amount display -------
            Text(
              'Raise to ${_formatAmount(_value.round())}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ------- Slider -------
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.raise,
                inactiveTrackColor: AppColors.surfaceLight,
                thumbColor: AppColors.raise,
                overlayColor: AppColors.raise.withOpacity(0.2),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                min: effectiveMin,
                max: effectiveMax,
                value: _value.clamp(effectiveMin, effectiveMax),
                divisions: (effectiveMax - effectiveMin).round().clamp(1, 1000),
                onChanged: (v) => setState(() => _value = v),
              ),
            ),

            // ------- Min / Max labels -------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatAmount(widget.minBet),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatAmount(widget.maxBet),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ------- Quick-bet buttons -------
            Row(
              children: [
                _quickBetButton('1/2 Pot', (widget.potAmount * 0.5)),
                const SizedBox(width: AppSpacing.xs),
                _quickBetButton('3/4 Pot', (widget.potAmount * 0.75)),
                const SizedBox(width: AppSpacing.xs),
                _quickBetButton('Pot', widget.potAmount.toDouble()),
                const SizedBox(width: AppSpacing.xs),
                _quickBetButton('All In', widget.maxBet.toDouble()),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // ------- Confirm / Cancel -------
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.textSecondary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => widget.onConfirm(_value.round()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.raise,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Raise ${_formatAmount(_value.round())}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickBetButton(String label, double amount) {
    return Expanded(
      child: InkWell(
        onTap: () => _setPreset(amount),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
