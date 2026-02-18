import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../providers/hand_history_provider.dart';
import '../widgets/hand_summary_card.dart';

/// Chat-like reverse-scroll timeline of all hands played in a room.
///
/// Newest hands appear at the bottom (like a messaging app). Scrolling up loads
/// older hands via pagination. Supports pull-to-refresh for the latest data.
class HandHistoryScreen extends ConsumerStatefulWidget {
  final String roomId;

  const HandHistoryScreen({super.key, required this.roomId});

  @override
  ConsumerState<HandHistoryScreen> createState() => _HandHistoryScreenState();
}

class _HandHistoryScreenState extends ConsumerState<HandHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Tracks which hand cards are expanded (by hand ID).
  final Set<String> _expandedHands = {};

  @override
  void initState() {
    super.initState();
    // Load initial data.
    Future.microtask(() {
      ref.read(handHistoryProvider(widget.roomId).notifier).loadHands();
    });

    // Listen for scroll-to-top to trigger loading older hands.
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// In a reverse list the "top" in visual terms is actually the end of the
  /// scroll extent. When the user scrolls up (towards older hands) the
  /// controller's position approaches maxScrollExtent.
  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(handHistoryProvider(widget.roomId).notifier).loadMoreHands();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(handHistoryProvider(widget.roomId).notifier).refresh();
  }

  void _toggleExpanded(String handId) {
    setState(() {
      if (_expandedHands.contains(handId)) {
        _expandedHands.remove(handId);
      } else {
        _expandedHands.add(handId);
      }
    });
  }

  // ----- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(handHistoryProvider(widget.roomId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Hand History',
          style: AppTypography.headline3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (state.hands.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  '${state.hands.length} hands',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(HandHistoryState state) {
    // Full-screen loading on first load
    if (state.isLoading && state.hands.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // Error state
    if (state.error != null && state.hands.isEmpty) {
      return _buildErrorState(state.error!);
    }

    // Empty state
    if (!state.isLoading && state.hands.isEmpty) {
      return _buildEmptyState();
    }

    // Hand list (reverse-scrolled like chat)
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: _onRefresh,
      child: _buildHandList(state),
    );
  }

  Widget _buildHandList(HandHistoryState state) {
    return CustomScrollView(
      controller: _scrollController,
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // Bottom padding (visually at top because reverse)
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.md)),

        // Hand cards
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final hand = state.hands[index];
              return HandSummaryCard(
                hand: hand,
                isExpanded: _expandedHands.contains(hand.handId),
                onTap: () => _toggleExpanded(hand.handId),
              );
            },
            childCount: state.hands.length,
          ),
        ),

        // Loading-more indicator (visually at top because reverse)
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          ),

        // "No more hands" indicator
        if (!state.hasMore && state.hands.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  'Beginning of hand history',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),

        // Top padding (visually at bottom because reverse)
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.md)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 80,
                color: AppColors.textSecondary.withOpacity(0.4),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No hands played yet',
                style: AppTypography.headline2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Once a hand is dealt, it will appear here\nlike a chat timeline.',
                textAlign: TextAlign.center,
                style: AppTypography.body1.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error.withOpacity(0.7),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Something went wrong',
                style: AppTypography.headline3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                error,
                textAlign: TextAlign.center,
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () {
                  ref
                      .read(handHistoryProvider(widget.roomId).notifier)
                      .loadHands();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
