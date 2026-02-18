import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/probability_api.dart';
import '../../auth/providers/auth_provider.dart';
import 'game_provider.dart';

// =============================================================================
// Probability state
// =============================================================================

/// Immutable state for win probability calculations.
class ProbabilityState {
  final double winProbability;
  final double tieProbability;
  final double lossProbability;
  final Map<String, double> handDistribution;
  final bool isLoading;
  final String? error;

  const ProbabilityState({
    this.winProbability = 0.0,
    this.tieProbability = 0.0,
    this.lossProbability = 0.0,
    this.handDistribution = const {},
    this.isLoading = false,
    this.error,
  });

  ProbabilityState copyWith({
    double? winProbability,
    double? tieProbability,
    double? lossProbability,
    Map<String, double>? handDistribution,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ProbabilityState(
      winProbability: winProbability ?? this.winProbability,
      tieProbability: tieProbability ?? this.tieProbability,
      lossProbability: lossProbability ?? this.lossProbability,
      handDistribution: handDistribution ?? this.handDistribution,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// =============================================================================
// Probability notifier
// =============================================================================

class ProbabilityNotifier extends StateNotifier<ProbabilityState> {
  final ProbabilityApi _probabilityApi;

  Timer? _debounceTimer;

  /// Track the last community card count so we only recalculate when it changes.
  int _lastCommunityCardCount = -1;

  /// Track the last hand state to detect street changes.
  String _lastHandState = '';

  ProbabilityNotifier(this._probabilityApi)
      : super(const ProbabilityState());

  /// Calculate win probability for the current hand.
  ///
  /// [holeCards] - the player's 2 hole cards (e.g. ["Ah", "Kd"]).
  /// [communityCards] - the current community cards on the board.
  /// [numOpponents] - number of active opponents.
  Future<void> calculate({
    required List<String> holeCards,
    required List<String> communityCards,
    required int numOpponents,
  }) async {
    if (holeCards.length < 2) return;
    if (numOpponents < 1) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _probabilityApi.calculateProbability(
        holeCards: holeCards,
        communityCards: communityCards,
        numOpponents: numOpponents,
      );

      if (!mounted) return;

      final distribution = <String, double>{};
      final rawDist = data['handDistribution'] as Map<String, dynamic>?;
      if (rawDist != null) {
        for (final entry in rawDist.entries) {
          distribution[entry.key] = (entry.value as num).toDouble();
        }
      }

      state = ProbabilityState(
        winProbability: (data['winProbability'] as num?)?.toDouble() ?? 0.0,
        tieProbability: (data['tieProbability'] as num?)?.toDouble() ?? 0.0,
        lossProbability: (data['lossProbability'] as num?)?.toDouble() ?? 0.0,
        handDistribution: distribution,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
    }
  }

  /// Called when game state changes. Debounces and only recalculates when
  /// the street changes (community card count or hand state changes).
  void onGameStateChanged({
    required List<String>? holeCards,
    required List<String> communityCards,
    required String handState,
    required int numOpponents,
  }) {
    // Skip if we don't have hole cards or hand is complete.
    if (holeCards == null || holeCards.length < 2) {
      _reset();
      return;
    }

    if (handState == 'SHOWDOWN' ||
        handState == 'SETTLEMENT' ||
        handState == 'FINISHED') {
      return;
    }

    // Only recalculate when the street actually changes.
    final cardCount = communityCards.length;
    if (cardCount == _lastCommunityCardCount &&
        handState == _lastHandState) {
      return;
    }

    _lastCommunityCardCount = cardCount;
    _lastHandState = handState;

    // Debounce the API call by 500ms.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      calculate(
        holeCards: holeCards,
        communityCards: communityCards,
        numOpponents: numOpponents,
      );
    });
  }

  void _reset() {
    _lastCommunityCardCount = -1;
    _lastHandState = '';
    _debounceTimer?.cancel();
    if (mounted) {
      state = const ProbabilityState();
    }
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return 'Probability calculation failed';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provides the [ProbabilityApi] backed by the application-level [Dio] instance.
final probabilityApiProvider = Provider<ProbabilityApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ProbabilityApi(dio);
});

/// Per-room probability state provider.
///
/// Watches [gameProvider] and auto-triggers probability calculation when
/// community cards change (new street dealt).
///
/// Usage:
/// ```dart
/// final probState = ref.watch(probabilityProvider(roomId));
/// ```
final probabilityProvider =
    StateNotifierProvider.family<ProbabilityNotifier, ProbabilityState, String>(
  (ref, roomId) {
    final probabilityApi = ref.watch(probabilityApiProvider);
    final notifier = ProbabilityNotifier(probabilityApi);

    // Watch game state and auto-trigger calculations on street changes.
    ref.listen<GameState>(
      gameProvider(roomId),
      (previous, next) {
        final hand = next.currentHand;
        if (hand == null) return;

        final myPlayer = next.myPlayer;
        final holeCards = myPlayer?.holeCards;

        // Count active (non-folded) opponents.
        final activeOpponents = hand.players
            .where((p) =>
                p.userId != next.myUserId &&
                p.status != 'FOLDED')
            .length;

        notifier.onGameStateChanged(
          holeCards: holeCards,
          communityCards: hand.communityCards,
          handState: hand.state,
          numOpponents: activeOpponents > 0 ? activeOpponents : 1,
        );
      },
      fireImmediately: true,
    );

    return notifier;
  },
);
