import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'bet_slider.dart';

/// Bottom action panel that appears when it is the local player's turn.
///
/// Displays a row of action buttons: Fold, Check/Call, Raise, All In.
/// Tapping Raise opens the [BetSlider] inline.
class ActionPanel extends StatefulWidget {
  /// The current highest bet on the table that must be matched.
  final int currentBet;

  /// The amount the current player has already bet this round.
  final int myCurrentBet;

  /// The player's remaining chip count.
  final int myChips;

  /// Total pot amount (passed to BetSlider for pot-relative shortcuts).
  final int potAmount;

  /// Minimum raise amount (e.g. big blind or min-raise).
  final int minRaise;

  /// Whether the action is currently being processed (disables buttons).
  final bool isProcessing;

  final VoidCallback onFold;
  final VoidCallback onCheck;
  final VoidCallback onCall;
  final ValueChanged<int> onRaise;
  final VoidCallback onAllIn;

  const ActionPanel({
    super.key,
    required this.currentBet,
    this.myCurrentBet = 0,
    required this.myChips,
    this.potAmount = 0,
    this.minRaise = 0,
    this.isProcessing = false,
    required this.onFold,
    required this.onCheck,
    required this.onCall,
    required this.onRaise,
    required this.onAllIn,
  });

  @override
  State<ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends State<ActionPanel> {
  bool _showSlider = false;

  /// Whether the player can check (no outstanding bet to match).
  bool get _canCheck => widget.currentBet <= widget.myCurrentBet;

  /// The amount needed to call.
  int get _callAmount =>
      (widget.currentBet - widget.myCurrentBet).clamp(0, widget.myChips);

  /// Effective minimum raise: at least minRaise, but never more than chips.
  int get _effectiveMinRaise {
    final min = widget.minRaise > 0 ? widget.minRaise : (widget.currentBet * 2);
    return min.clamp(1, widget.myChips);
  }

  /// Whether a raise is possible (player has more chips than a call).
  bool get _canRaise => widget.myChips > _callAmount && _callAmount < widget.myChips;

  String _formatAmount(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSlider) {
      return BetSlider(
        minBet: _effectiveMinRaise,
        maxBet: widget.myChips,
        currentBet: widget.currentBet,
        potAmount: widget.potAmount,
        onConfirm: (amount) {
          setState(() => _showSlider = false);
          widget.onRaise(amount);
        },
        onCancel: () => setState(() => _showSlider = false),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // FOLD
            _actionButton(
              label: 'FOLD',
              color: AppColors.fold,
              onTap: widget.isProcessing ? null : widget.onFold,
            ),
            const SizedBox(width: AppSpacing.sm),

            // CHECK or CALL
            if (_canCheck)
              _actionButton(
                label: 'CHECK',
                color: AppColors.check,
                onTap: widget.isProcessing ? null : widget.onCheck,
              )
            else
              _actionButton(
                label: 'CALL\n${_formatAmount(_callAmount)}',
                color: AppColors.call,
                onTap: widget.isProcessing ? null : widget.onCall,
              ),
            const SizedBox(width: AppSpacing.sm),

            // RAISE (opens slider)
            if (_canRaise) ...[
              _actionButton(
                label: 'RAISE',
                color: AppColors.raise,
                onTap: widget.isProcessing
                    ? null
                    : () => setState(() => _showSlider = true),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],

            // ALL IN
            _actionButton(
              label: 'ALL IN\n${_formatAmount(widget.myChips)}',
              color: AppColors.allIn,
              onTap: widget.isProcessing ? null : widget.onAllIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDisabled ? color.withOpacity(0.3) : color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDisabled ? Colors.white38 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
