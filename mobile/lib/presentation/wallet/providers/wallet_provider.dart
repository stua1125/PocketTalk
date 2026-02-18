import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/remote/wallet_api.dart';
import '../../../domain/entities/wallet.dart';
import '../../auth/providers/auth_provider.dart';

// Wallet state
class WalletState {
  final WalletInfo? walletInfo;
  final List<WalletTransaction> transactions;
  final bool isLoading;
  final bool isClaimingReward;
  final bool isLoadingMore;
  final bool hasMoreTransactions;
  final String? error;

  const WalletState({
    this.walletInfo,
    this.transactions = const [],
    this.isLoading = false,
    this.isClaimingReward = false,
    this.isLoadingMore = false,
    this.hasMoreTransactions = true,
    this.error,
  });

  WalletState copyWith({
    WalletInfo? walletInfo,
    List<WalletTransaction>? transactions,
    bool? isLoading,
    bool? isClaimingReward,
    bool? isLoadingMore,
    bool? hasMoreTransactions,
    String? error,
  }) {
    return WalletState(
      walletInfo: walletInfo ?? this.walletInfo,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isClaimingReward: isClaimingReward ?? this.isClaimingReward,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreTransactions: hasMoreTransactions ?? this.hasMoreTransactions,
      error: error,
    );
  }
}

// Wallet notifier
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletApi _walletApi;
  int _currentPage = 0;
  static const _pageSize = 20;

  WalletNotifier(this._walletApi) : super(const WalletState());

  Future<void> loadWallet() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final balanceData = await _walletApi.getBalance();
      final walletInfo = WalletInfo.fromJson(balanceData);

      _currentPage = 0;
      final transactionsData = await _walletApi.getTransactions(
        page: _currentPage,
        size: _pageSize,
      );
      final transactions = transactionsData
          .map((json) =>
              WalletTransaction.fromJson(json as Map<String, dynamic>))
          .toList();

      state = WalletState(
        walletInfo: walletInfo,
        transactions: transactions,
        hasMoreTransactions: transactions.length >= _pageSize,
      );
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] ?? 'Failed to load wallet';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load wallet');
    }
  }

  Future<void> claimDailyReward() async {
    state = state.copyWith(isClaimingReward: true, error: null);
    try {
      final data = await _walletApi.claimDailyReward();
      final updatedWallet = WalletInfo.fromJson(data);

      // Reload transactions to include the new reward transaction
      _currentPage = 0;
      final transactionsData = await _walletApi.getTransactions(
        page: _currentPage,
        size: _pageSize,
      );
      final transactions = transactionsData
          .map((json) =>
              WalletTransaction.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        walletInfo: updatedWallet,
        transactions: transactions,
        isClaimingReward: false,
        hasMoreTransactions: transactions.length >= _pageSize,
      );
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] ?? 'Failed to claim daily reward';
      state = state.copyWith(isClaimingReward: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isClaimingReward: false,
        error: 'Failed to claim daily reward',
      );
    }
  }

  Future<void> loadMoreTransactions() async {
    if (state.isLoadingMore || !state.hasMoreTransactions) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      _currentPage++;
      final transactionsData = await _walletApi.getTransactions(
        page: _currentPage,
        size: _pageSize,
      );
      final newTransactions = transactionsData
          .map((json) =>
              WalletTransaction.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        transactions: [...state.transactions, ...newTransactions],
        isLoadingMore: false,
        hasMoreTransactions: newTransactions.length >= _pageSize,
      );
    } catch (e) {
      _currentPage--;
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

// Providers
final walletApiProvider = Provider<WalletApi>((ref) {
  final dio = ref.watch(dioProvider);
  return WalletApi(dio);
});

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.watch(walletApiProvider));
});
