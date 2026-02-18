import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/card.dart';
import '../../../domain/entities/hand.dart';
import '../../common/poker_card_widget.dart';
import 'action_timeline.dart';

/// Card widget that represents a single hand in the history timeline.
///
/// Shows a compact summary by default. When tapped, it expands to reveal the
/// full [ActionTimeline] with every action in the hand.
class HandSummaryCard extends StatelessWidget {
  final GameHand hand;
  final bool isExpanded;
  final VoidCallback onTap;

  const HandSummaryCard({
    super.key,
    required this.hand,
    required this.isExpanded,
    required this.onTap,
  });

  // ----- helpers -----------------------------------------------------------

  /// Produce a human-readable "time ago" string.
  String _timeAgo(GameHand hand) {
    // Prefer completedAt; fall back to the last action's timestamp; then a
    // static label.
    DateTime? reference;
    if (hand.actions.isNotEmpty && hand.actions.last.createdAt != null) {
      reference = hand.actions.last.createdAt;
    }
    if (reference == null) return '';

    final diff = DateTime.now().difference(reference);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  /// True if the hand has reached a terminal state.
  bool get _isCompleted => hand.isComplete;

  /// Find the winner(s) in the player list.
  List<HandPlayerInfo> get _winners =>
      hand.players.where((p) => p.wonAmount > 0).toList();

  /// Parse community card codes into [PokerCard] objects, silently skipping
  /// any that fail to parse.
  List<PokerCard> get _communityCards {
    return hand.communityCards
        .map((code) {
          try {
            return PokerCard.fromCode(code);
          } catch (_) {
            return null;
          }
        })
        .whereType<PokerCard>()
        .toList();
  }

  // ----- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded
                ? AppColors.primaryLight.withOpacity(0.4)
                : AppColors.surfaceLight,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isExpanded ? 0.25 : 0.15),
              blurRadius: isExpanded ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildCommunityCards(),
            _buildPotAndWinner(),
            // Expanded detail
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
            // Expand hint
            _buildExpandHint(),
          ],
        ),
      ),
    );
  }

  // --- header: hand number + time + state badge ---
  Widget _buildHeader() {
    final timeAgo = _timeAgo(hand);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          // Hand number
          Text(
            '#${hand.handNumber}',
            style: AppTypography.headline3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (timeAgo.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              timeAgo,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          // State badge
          _buildStateBadge(),
        ],
      ),
    );
  }

  Widget _buildStateBadge() {
    final bool completed = _isCompleted;
    final Color bgColor =
        completed ? AppColors.success.withOpacity(0.15) : AppColors.warning.withOpacity(0.15);
    final Color fgColor = completed ? AppColors.success : AppColors.warning;
    final String label = completed ? 'Completed' : hand.state;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // --- community cards row ---
  Widget _buildCommunityCards() {
    final cards = _communityCards;
    if (cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildEmptyCardSlot(),
            ),
          ),
        ),
      );
    }

    // Show dealt cards plus remaining empty slots.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          for (int i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: i < cards.length
                  ? PokerCardWidget(
                      card: cards[i],
                      width: 36,
                      height: 50,
                    )
                  : _buildEmptyCardSlot(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCardSlot() {
    return Container(
      width: 36,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
    );
  }

  // --- pot + winner info ---
  Widget _buildPotAndWinner() {
    final winners = _winners;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          // Pot
          Icon(
            Icons.toll,
            size: 14,
            color: AppColors.chipGold.withOpacity(0.8),
          ),
          const SizedBox(width: 4),
          Text(
            'Pot: ${hand.potTotal}',
            style: AppTypography.body2.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Winner
          if (winners.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 14,
                  color: AppColors.chipGold,
                ),
                const SizedBox(width: 4),
                Text(
                  winners.length == 1
                      ? '${winners.first.nickname} won ${winners.first.wonAmount}'
                      : '${winners.length} winners',
                  style: AppTypography.body2.copyWith(
                    color: AppColors.chipGold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --- expanded content: full action timeline ---
  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.surfaceLight, height: 1),
          const SizedBox(height: AppSpacing.sm),
          // Player summary
          if (hand.players.isNotEmpty) ...[
            Text(
              'Players',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: hand.players.map((p) {
                final isWinner = p.wonAmount > 0;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: isWinner
                        ? AppColors.chipGold.withOpacity(0.3)
                        : AppColors.surfaceLight,
                    radius: 12,
                    child: Text(
                      p.nickname.isNotEmpty ? p.nickname[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: isWinner
                            ? AppColors.chipGold
                            : AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  label: Text(
                    '${p.nickname}${isWinner ? " +${p.wonAmount}" : ""}',
                    style: AppTypography.caption.copyWith(
                      color: isWinner
                          ? AppColors.chipGold
                          : AppColors.textPrimary,
                      fontWeight:
                          isWinner ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  backgroundColor: AppColors.surfaceLight,
                  side: BorderSide(
                    color: isWinner
                        ? AppColors.chipGold.withOpacity(0.3)
                        : Colors.transparent,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Action timeline
          Text(
            'Actions',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ActionTimeline(
            actions: hand.actions,
            players: hand.players,
          ),
        ],
      ),
    );
  }

  // --- expand/collapse hint ---
  Widget _buildExpandHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Center(
        child: Icon(
          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: AppColors.textSecondary.withOpacity(0.5),
          size: 20,
        ),
      ),
    );
  }
}
