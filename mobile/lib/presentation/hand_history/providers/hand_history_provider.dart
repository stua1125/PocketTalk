import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/game_api.dart';
import '../../../domain/entities/hand.dart';
import '../../auth/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class HandHistoryState {
  final List<GameHand> hands;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const HandHistoryState({
    this.hands = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  HandHistoryState copyWith({
    List<GameHand>? hands,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return HandHistoryState(
      hands: hands ?? this.hands,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class HandHistoryNotifier extends StateNotifier<HandHistoryState> {
  final GameApi _gameApi;
  final String roomId;

  static const _pageSize = 20;

  HandHistoryNotifier(this._gameApi, this.roomId)
      : super(const HandHistoryState());

  /// Initial load of hand history.
  Future<void> loadHands() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _gameApi.getHandHistory(
        roomId,
        page: 0,
        size: _pageSize,
      );
      final hands = data
          .map((json) => GameHand.fromJson(json as Map<String, dynamic>))
          .toList();

      state = HandHistoryState(
        hands: hands,
        currentPage: 0,
        hasMore: hands.length >= _pageSize,
      );
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? 'Failed to load history';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load hand history',
      );
    }
  }

  /// Load the next page of older hands (triggered when scrolling to top).
  Future<void> loadMoreHands() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final data = await _gameApi.getHandHistory(
        roomId,
        page: nextPage,
        size: _pageSize,
      );
      final newHands = data
          .map((json) => GameHand.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        // Older hands are prepended (they appear at the top in reverse scroll)
        hands: [...newHands, ...state.hands],
        currentPage: nextPage,
        isLoadingMore: false,
        hasMore: newHands.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Pull-to-refresh: reload from page 0.
  Future<void> refresh() async {
    await loadHands();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final gameApiProvider = Provider<GameApi>((ref) {
  final dio = ref.watch(dioProvider);
  return GameApi(dio);
});

final handHistoryProvider = StateNotifierProvider.family<
    HandHistoryNotifier, HandHistoryState, String>((ref, roomId) {
  final gameApi = ref.watch(gameApiProvider);
  return HandHistoryNotifier(gameApi, roomId);
});
