import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/hand.dart';

/// Chat-style vertical timeline of actions within a single hand.
///
/// Player actions appear as small coloured bubbles on the left. System events
/// (deal, showdown, win) are centred with a muted style. A thin vertical line
/// connects all entries.
class ActionTimeline extends StatelessWidget {
  final List<HandActionInfo> actions;
  final List<HandPlayerInfo> players;

  const ActionTimeline({
    super.key,
    required this.actions,
    this.players = const [],
  });

  // ----- helpers -----------------------------------------------------------

  /// Resolve a userId to a nickname using the player list.
  String _nickname(String? userId) {
    if (userId == null || userId.isEmpty) return 'System';
    final match = players.where((p) => p.userId == userId);
    if (match.isNotEmpty) return match.first.nickname;
    return 'Player';
  }

  /// Returns true when this action type should be rendered as a centred
  /// system event rather than a player bubble.
  bool _isSystemEvent(String actionType) {
    final normalised = actionType.toUpperCase().replaceAll('_', '');
    return const {
      'DEALFLOP',
      'DEALTURN',
      'DEALRIVER',
      'SHOWDOWN',
      'SETTLEMENT',
      'DEAL',
      'DEALCOMMUNITY',
    }.contains(normalised);
  }

  /// Returns true when this action represents a player winning the pot.
  bool _isWinEvent(String actionType) {
    final normalised = actionType.toUpperCase().replaceAll('_', '');
    return normalised == 'WINPOT' || normalised == 'WIN';
  }

  /// Colour for the action chip/bubble.
  Color _actionColor(String actionType) {
    final normalised = actionType.toUpperCase().replaceAll('_', '');
    return switch (normalised) {
      'FOLD' => AppColors.fold,
      'CHECK' => AppColors.check,
      'CALL' => AppColors.call,
      'RAISE' || 'BET' => AppColors.raise,
      'ALLIN' => AppColors.allIn,
      'SMALLBLIND' || 'SB' || 'BIGBLIND' || 'BB' => AppColors.primaryLight,
      'WINPOT' || 'WIN' => AppColors.chipGold,
      _ => AppColors.textSecondary,
    };
  }

  /// Human-readable label for an action type.
  String _actionLabel(String actionType) {
    final normalised = actionType.toUpperCase().replaceAll('_', '');
    return switch (normalised) {
      'FOLD' => 'FOLD',
      'CHECK' => 'CHECK',
      'CALL' => 'CALL',
      'RAISE' => 'RAISE',
      'BET' => 'BET',
      'ALLIN' => 'ALL-IN',
      'SMALLBLIND' || 'SB' => 'Small Blind',
      'BIGBLIND' || 'BB' => 'Big Blind',
      'DEALFLOP' || 'DEALCOMMUNITY' || 'DEAL' => 'Flop Dealt',
      'DEALTURN' => 'Turn Dealt',
      'DEALRIVER' => 'River Dealt',
      'SHOWDOWN' => 'Showdown',
      'SETTLEMENT' => 'Settlement',
      'WINPOT' || 'WIN' => 'Wins Pot',
      _ => actionType,
    };
  }

  // ----- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          'No actions recorded.',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < actions.length; i++)
          _buildEntry(actions[i], isLast: i == actions.length - 1),
      ],
    );
  }

  Widget _buildEntry(HandActionInfo action, {required bool isLast}) {
    final isSystem = _isSystemEvent(action.actionType);
    final isWin = _isWinEvent(action.actionType);

    if (isSystem) {
      return _buildSystemEvent(action, isLast: isLast);
    }
    if (isWin) {
      return _buildWinEvent(action, isLast: isLast);
    }
    return _buildPlayerAction(action, isLast: isLast);
  }

  // --- system event (centred) ---
  Widget _buildSystemEvent(HandActionInfo action, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline line
          _buildTimelineLine(
            color: AppColors.textSecondary.withOpacity(0.3),
            isLast: isLast,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Centred label
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _actionLabel(action.actionType),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- win event (gold accent) ---
  Widget _buildWinEvent(HandActionInfo action, {required bool isLast}) {
    final name = _nickname(action.userId);
    final amount = action.amount > 0 ? ' ${action.amount}' : '';
    return IntrinsicHeight(
      child: Row(
        children: [
          _buildTimelineLine(
            color: AppColors.chipGold,
            isLast: isLast,
            dotColor: AppColors.chipGold,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.chipGold.withOpacity(0.15),
                    AppColors.chipGold.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.chipGold.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: AppColors.chipGold,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: name,
                            style: AppTypography.body2.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: ' wins$amount',
                            style: AppTypography.body2.copyWith(
                              color: AppColors.chipGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- player action bubble ---
  Widget _buildPlayerAction(HandActionInfo action, {required bool isLast}) {
    final name = _nickname(action.userId);
    final color = _actionColor(action.actionType);
    final label = _actionLabel(action.actionType);
    final amountStr = action.amount > 0 ? ' ${action.amount}' : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineLine(
            color: color.withOpacity(0.5),
            isLast: isLast,
            dotColor: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.20),
                ),
              ),
              child: Row(
                children: [
                  // Player name
                  Text(
                    name,
                    style: AppTypography.body2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Action badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$label$amountStr',
                      style: AppTypography.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- timeline vertical line + dot ---
  Widget _buildTimelineLine({
    required Color color,
    required bool isLast,
    Color? dotColor,
  }) {
    return SizedBox(
      width: 20,
      child: Column(
        children: [
          // Top segment
          Expanded(
            child: Container(
              width: 2,
              color: color,
            ),
          ),
          // Dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor ?? color,
            ),
          ),
          // Bottom segment
          Expanded(
            child: Container(
              width: isLast ? 0 : 2,
              color: isLast ? Colors.transparent : color,
            ),
          ),
        ],
      ),
    );
  }
}
