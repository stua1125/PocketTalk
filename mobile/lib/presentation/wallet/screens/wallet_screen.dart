import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/wallet.dart';
import '../../common/chip_display.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(walletProvider.notifier).loadWallet());
    _scrollController.addListener(_onScroll);
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Trigger rebuild to update countdown display
      if (mounted) setState(() {});
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(walletProvider.notifier).loadMoreTransactions();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(walletProvider.notifier).loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);

    ref.listen<WalletState>(walletProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: walletState.isLoading && walletState.walletInfo == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.chipGold),
            )
          : RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.chipGold,
              backgroundColor: AppColors.surface,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Balance card
                  SliverToBoxAdapter(
                    child: _buildBalanceCard(walletState.walletInfo),
                  ),
                  // Daily reward button
                  SliverToBoxAdapter(
                    child: _buildDailyRewardSection(walletState),
                  ),
                  // Transaction history header
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // Transaction list
                  if (walletState.transactions.isEmpty &&
                      !walletState.isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index < walletState.transactions.length) {
                            return _buildTransactionItem(
                              walletState.transactions[index],
                            );
                          }
                          // Loading more indicator
                          if (walletState.isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.chipGold,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (!walletState.hasMoreTransactions &&
                              walletState.transactions.isNotEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(
                                child: Text(
                                  'No more transactions',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                        childCount: walletState.transactions.length +
                            (walletState.isLoadingMore ||
                                    (!walletState.hasMoreTransactions &&
                                        walletState.transactions.isNotEmpty)
                                ? 1
                                : 0),
                      ),
                    ),
                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(WalletInfo? walletInfo) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B5E20),
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.chipGold.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Your Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ChipDisplay(
            amount: walletInfo?.balance ?? 0,
            fontSize: 36,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Decorative line
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.chipGold.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatFullAmount(walletInfo?.balance ?? 0),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyRewardSection(WalletState walletState) {
    final walletInfo = walletState.walletInfo;
    final isAvailable = walletInfo?.dailyRewardAvailable ?? false;
    final isClaiming = walletState.isClaimingReward;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: isAvailable
          ? _buildClaimButton(isClaiming)
          : _buildAlreadyClaimedButton(walletInfo),
    );
  }

  Widget _buildClaimButton(bool isClaiming) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isClaiming
            ? null
            : () => ref.read(walletProvider.notifier).claimDailyReward(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.success.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: isClaiming
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 24),
                  SizedBox(width: AppSpacing.sm),
                  Text(
                    'Claim Daily Reward (+1,000)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAlreadyClaimedButton(WalletInfo? walletInfo) {
    final countdown = _getCountdownText(walletInfo?.lastDailyRewardAt);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceLight,
          disabledBackgroundColor: AppColors.surfaceLight,
          disabledForegroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 24, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already Claimed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (countdown != null)
                  Text(
                    'Next reward in $countdown',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransaction transaction) {
    final isPositive = transaction.amount >= 0;
    final amountColor = isPositive ? AppColors.success : AppColors.error;
    final amountPrefix = isPositive ? '+' : '';
    final icon = _getTransactionIcon(transaction.type);
    final iconColor = _getTransactionIconColor(transaction.type);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          // Description and time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ??
                      _getTransactionLabel(transaction.type),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTransactionTime(transaction.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Amount and balance after
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix${_formatAmount(transaction.amount)}',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bal: ${_formatAmount(transaction.balanceAfter)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Your transaction history will appear here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // -- Helper methods --

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'DAILY_REWARD':
        return Icons.card_giftcard;
      case 'WIN':
        return Icons.arrow_upward;
      case 'LOSS':
        return Icons.arrow_downward;
      case 'BUY_IN':
        return Icons.login;
      case 'CASH_OUT':
        return Icons.logout;
      case 'BONUS':
        return Icons.star;
      case 'REFUND':
        return Icons.replay;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _getTransactionIconColor(String type) {
    switch (type) {
      case 'DAILY_REWARD':
        return AppColors.chipGold;
      case 'WIN':
        return AppColors.success;
      case 'LOSS':
        return AppColors.error;
      case 'BUY_IN':
        return AppColors.chipBlue;
      case 'CASH_OUT':
        return AppColors.warning;
      case 'BONUS':
        return AppColors.chipGold;
      case 'REFUND':
        return AppColors.chipBlue;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTransactionLabel(String type) {
    switch (type) {
      case 'DAILY_REWARD':
        return 'Daily Reward';
      case 'WIN':
        return 'Hand Won';
      case 'LOSS':
        return 'Hand Lost';
      case 'BUY_IN':
        return 'Table Buy-In';
      case 'CASH_OUT':
        return 'Cash Out';
      case 'BONUS':
        return 'Bonus';
      case 'REFUND':
        return 'Refund';
      default:
        return type;
    }
  }

  String _formatAmount(int amount) {
    final absAmount = amount.abs();
    if (absAmount >= 1000000) {
      return '${(absAmount / 1000000).toStringAsFixed(1)}M';
    }
    if (absAmount >= 1000) {
      return '${(absAmount / 1000).toStringAsFixed(1)}K';
    }
    return absAmount.toString();
  }

  String _formatFullAmount(int amount) {
    // Format with comma separators
    final str = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} chips';
  }

  String _formatTransactionTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  String? _getCountdownText(DateTime? lastRewardAt) {
    if (lastRewardAt == null) return null;

    // Assume daily reward resets 24 hours after last claim
    final nextRewardAt = lastRewardAt.add(const Duration(hours: 24));
    final now = DateTime.now();
    final remaining = nextRewardAt.difference(now);

    if (remaining.isNegative) return null;

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
