import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/game_api.dart';
import '../../../data/datasources/remote/websocket_service.dart';
import '../../../domain/entities/hand.dart';
import '../../auth/providers/auth_provider.dart';
import 'websocket_provider.dart';

// =============================================================================
// Game state
// =============================================================================

/// Immutable state object for the game screen.
class GameState {
  final GameHand? currentHand;
  final String roomId;
  final String? myUserId;
  final bool isLoading;
  final String? error;

  const GameState({
    this.currentHand,
    required this.roomId,
    this.myUserId,
    this.isLoading = false,
    this.error,
  });

  // ---------------------------------------------------------------------------
  // Derived properties
  // ---------------------------------------------------------------------------

  /// The current user's player info in this hand, or `null` when there is no
  /// active hand or the user is not seated.
  HandPlayerInfo? get myPlayer {
    if (currentHand == null || myUserId == null) return null;
    try {
      return currentHand!.players.firstWhere((p) => p.userId == myUserId);
    } catch (_) {
      return null;
    }
  }

  /// The hole cards that were privately dealt to the current user.
  List<String>? get myHoleCards => myPlayer?.holeCards;

  /// Whether it is currently the local user's turn to act.
  bool get isMyTurn {
    if (currentHand == null || myUserId == null) return false;
    if (currentHand!.isComplete) return false;
    return currentHand!.currentPlayerId == myUserId;
  }

  /// The highest bet posted in the current betting round among all players.
  int get currentBet {
    if (currentHand == null) return 0;
    int maxBet = 0;
    for (final p in currentHand!.players) {
      if (p.betTotal > maxBet) maxBet = p.betTotal;
    }
    return maxBet;
  }

  GameState copyWith({
    GameHand? currentHand,
    String? roomId,
    String? myUserId,
    bool? isLoading,
    String? error,
    bool clearHand = false,
    bool clearError = false,
  }) {
    return GameState(
      currentHand: clearHand ? null : (currentHand ?? this.currentHand),
      roomId: roomId ?? this.roomId,
      myUserId: myUserId ?? this.myUserId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// =============================================================================
// Game notifier
// =============================================================================

class GameNotifier extends StateNotifier<GameState> {
  final GameApi _gameApi;
  final WebSocketService _wsService;

  StreamSubscription<Map<String, dynamic>>? _gameEventSub;
  StreamSubscription<Map<String, dynamic>>? _holeCardsSub;
  StreamSubscription<Map<String, dynamic>>? _notificationSub;

  GameNotifier(
    this._gameApi,
    this._wsService,
    String roomId,
    String? myUserId,
  ) : super(GameState(roomId: roomId, myUserId: myUserId)) {
    _subscribeToStreams();
  }

  // ---------------------------------------------------------------------------
  // Stream subscriptions
  // ---------------------------------------------------------------------------

  void _subscribeToStreams() {
    _gameEventSub = _wsService.gameEvents.listen(
      _handleGameEvent,
      onError: (e) {
        if (mounted) {
          state = state.copyWith(error: 'Game event stream error');
        }
      },
    );

    _holeCardsSub = _wsService.holeCards.listen(
      _handleHoleCards,
      onError: (_) {},
    );

    _notificationSub = _wsService.notifications.listen(
      _handleNotification,
      onError: (_) {},
    );
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Ask the server to deal a new hand for this room.
  Future<void> startHand() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _gameApi.startHand(state.roomId);
      if (!mounted) return;
      final hand = GameHand.fromJson(data);
      state = state.copyWith(currentHand: hand, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
    }
  }

  /// Submit a player action: FOLD, CHECK, CALL, RAISE, or ALL_IN.
  Future<void> performAction(String actionType, {int? amount}) async {
    final hand = state.currentHand;
    if (hand == null) return;

    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final action = <String, dynamic>{
        'action': actionType,
        if (amount != null) 'amount': amount,
      };
      final data = await _gameApi.processAction(hand.handId, action);
      if (!mounted) return;
      final updatedHand = GameHand.fromJson(data);
      state = state.copyWith(currentHand: updatedHand, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = _extractError(e);
      state = state.copyWith(isLoading: false, error: errorMsg);
      // Re-fetch from server to fix stale state after action error.
      await refreshHand(hand.handId);
    }
  }

  /// Re-fetch the hand state from the REST API (e.g. after reconnecting).
  Future<void> refreshHand(String handId) async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _gameApi.getHand(handId);
      if (!mounted) return;
      final hand = GameHand.fromJson(data);
      state = state.copyWith(currentHand: hand, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
    }
  }

  /// Clear the current hand (e.g. after settlement).
  void clearHand() {
    if (!mounted) return;
    state = state.copyWith(clearHand: true);
  }

  // ---------------------------------------------------------------------------
  // WebSocket event handlers
  // ---------------------------------------------------------------------------

  void _handleGameEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final type = event['type'] as String? ?? '';

    switch (type) {
      case 'HAND_STARTED':
      case 'PLAYER_ACTION':
      case 'STATE_CHANGED':
      case 'COMMUNITY_CARDS':
      case 'SHOWDOWN':
      case 'HAND_SETTLED':
        final data = event['payload'] as Map<String, dynamic>? ?? event;
        final hand = GameHand.fromJson(data);
        // Only apply updates for our room.
        if (hand.roomId == state.roomId || hand.roomId.isEmpty) {
          state = state.copyWith(currentHand: hand);
        }
        break;

      default:
        // Unknown event type -- ignore silently.
        break;
    }
  }

  void _handleHoleCards(Map<String, dynamic> data) {
    if (!mounted) return;
    final hand = state.currentHand;
    if (hand == null) return;

    final cards = (data['cards'] as List<dynamic>?)
        ?.map((c) => c as String)
        .toList();
    if (cards == null || cards.isEmpty) return;

    // Merge the private hole cards into the current user's player info.
    final updatedPlayers = hand.players.map((p) {
      if (p.userId == state.myUserId) {
        return p.copyWith(holeCards: cards);
      }
      return p;
    }).toList();

    state = state.copyWith(
      currentHand: hand.copyWith(players: updatedPlayers),
    );
  }

  void _handleNotification(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = data['type'] as String? ?? '';

    if (type == 'YOUR_TURN') {
      // The server explicitly tells us it's our turn. If the currentPlayerId
      // was already set via the game event, this is a no-op. Otherwise, update.
      final handId = data['handId'] as String?;
      final hand = state.currentHand;
      if (hand != null && handId == hand.handId && state.myUserId != null) {
        state = state.copyWith(
          currentHand: hand.copyWith(currentPlayerId: state.myUserId),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'] as String;
      }
    }
    if (e is Exception) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _gameEventSub?.cancel();
    _holeCardsSub?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provides the [GameApi] backed by the application-level [Dio] instance.
final gameApiProvider = Provider<GameApi>((ref) {
  final dio = ref.watch(dioProvider);
  return GameApi(dio);
});

/// Per-room game state provider.
///
/// Usage:
/// ```dart
/// final gameState = ref.watch(gameProvider(roomId));
/// ref.read(gameProvider(roomId).notifier).startHand();
/// ```
final gameProvider =
    StateNotifierProvider.family<GameNotifier, GameState, String>(
  (ref, roomId) {
    final gameApi = ref.watch(gameApiProvider);
    final wsService = ref.watch(webSocketServiceProvider);
    final authState = ref.watch(authProvider);
    final myUserId = authState.user?.id;

    return GameNotifier(gameApi, wsService, roomId, myUserId);
  },
);
