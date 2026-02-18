import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../domain/entities/card.dart';
import '../../../domain/entities/hand.dart';
import '../../chat/providers/emoji_provider.dart';
import '../../chat/widgets/chat_overlay.dart';
import '../../chat/widgets/emoji_overlay.dart';
import '../../chat/widgets/emoji_picker.dart';
import '../../common/poker_card_widget.dart';
import '../../common/widgets/connection_status_bar.dart';
import '../../common/widgets/empty_state.dart';
import '../../common/widgets/error_dialog.dart';
import '../providers/game_provider.dart';
import '../providers/probability_provider.dart';
import '../providers/websocket_provider.dart';
import '../widgets/action_panel.dart';
import '../widgets/hand_strength_bar.dart';
import '../widgets/player_seat.dart';
import '../widgets/poker_table.dart';
import '../widgets/turn_timer_bar.dart';
import '../widgets/win_probability_gauge.dart';

/// The main game screen -- the core poker experience.
///
/// Connects to WebSocket on entry, joins the room, and renders the poker table,
/// community cards, player seats, pot display, and the action panel.
///
/// Performance notes:
/// - Heavy sub-widgets are wrapped in [RepaintBoundary] to isolate repaints.
/// - [ref.watch] uses [select] where possible to minimise unnecessary rebuilds.
class GameScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _showEmojiPicker = false;
  Timer? _heartbeatTimer;
  DateTime _lastActivity = DateTime.now();

  static const _heartbeatInterval = Duration(seconds: 5);
  static const _activityTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();

    // Ensure the WebSocket is connected and we are subscribed to this room.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectAndJoin();
    });

    // Start periodic heartbeat
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeatIfActive());
  }

  Future<void> _connectAndJoin() async {
    // Connect WebSocket if not already connected.
    final wsNotifier = ref.read(webSocketConnectionProvider.notifier);
    await wsNotifier.connect();

    // Join the room's STOMP topics.
    ref.read(roomSubscriptionProvider(widget.roomId).notifier).join();

    // Send initial heartbeat
    _recordActivity();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  /// Record user activity (called on any interaction).
  void _recordActivity() {
    _lastActivity = DateTime.now();
    // Send an immediate heartbeat on activity
    final wsService = ref.read(webSocketServiceProvider);
    wsService.sendHeartbeat(widget.roomId);
  }

  /// Send heartbeat only if the user has been active recently.
  void _sendHeartbeatIfActive() {
    final elapsed = DateTime.now().difference(_lastActivity);
    if (elapsed < _activityTimeout) {
      final wsService = ref.read(webSocketServiceProvider);
      wsService.sendHeartbeat(widget.roomId);
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _performAction(String actionType, {int? amount}) {
    ref
        .read(gameProvider(widget.roomId).notifier)
        .performAction(actionType, amount: amount);
  }

  void _startHand() {
    ref.read(gameProvider(widget.roomId).notifier).startHand();
  }

  // ---------------------------------------------------------------------------
  // Helpers to map server data to existing widget models
  // ---------------------------------------------------------------------------

  /// Build the list of [PlayerSeatData] that [PokerTable] expects.
  ///
  /// Players are placed at their absolute server seat index (0-based).
  /// Seat 0 is at the bottom of the table, and positions go clockwise.
  List<PlayerSeatData?> _buildPlayerSeats(GameState gameState, int maxPlayers) {
    final seats = List<PlayerSeatData?>.filled(maxPlayers, null);
    final hand = gameState.currentHand;
    if (hand == null) return seats;

    for (final player in hand.players) {
      final seatIndex = player.seatNumber;
      if (seatIndex < 0 || seatIndex >= maxPlayers) continue;

      seats[seatIndex] = PlayerSeatData(
        id: player.userId,
        nickname: player.nickname,
        avatarUrl: player.avatarUrl,
        chipCount: player.chipCount,
        currentBet: player.betTotal > 0 ? player.betTotal : null,
        status: _mapPlayerStatus(player.status),
        isCurrentTurn: hand.currentPlayerId == player.userId,
        isDealer: player.isDealer,
      );
    }

    return seats;
  }

  PlayerStatus _mapPlayerStatus(String serverStatus) {
    switch (serverStatus.toUpperCase()) {
      case 'ACTIVE':
        return PlayerStatus.active;
      case 'FOLDED':
        return PlayerStatus.folded;
      case 'ALL_IN':
        return PlayerStatus.allIn;
      case 'SITTING_OUT':
        return PlayerStatus.sittingOut;
      default:
        return PlayerStatus.active;
    }
  }

  /// Parse the community card codes (e.g. "Ah", "Td") into [PokerCard] objects
  /// that [CommunityCards] / [PokerTable] expect.
  List<PokerCard> _buildCommunityCards(GameState gameState) {
    final hand = gameState.currentHand;
    if (hand == null) return const [];
    try {
      return hand.communityCards.map((c) => PokerCard.fromCode(c)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Whether the local player can start a new hand.
  ///
  /// Conditions: there is no active hand (or the current hand is complete),
  /// and the player is the room owner. The room owner check is a best-effort
  /// heuristic: we cannot know for sure here, so we rely on the server to
  /// reject unauthorised attempts with a helpful error message.
  bool _canStartHand(GameState gameState) {
    if (gameState.isLoading) return false;
    final hand = gameState.currentHand;
    return hand == null || hand.isComplete;
  }

  int _getMyChips(GameState gameState) {
    return gameState.myPlayer?.chipCount ?? 0;
  }

  int _getCurrentBet(GameState gameState) {
    return gameState.currentBet;
  }

  int _getMyCurrentBet(GameState gameState) {
    return gameState.myPlayer?.betTotal ?? 0;
  }

  int _getPotAmount(GameState gameState) {
    return gameState.currentHand?.potTotal ?? 0;
  }

  /// A key that changes whenever a new turn begins, so the timer bar resets.
  String _turnResetKey(GameState gameState) {
    final hand = gameState.currentHand;
    if (hand == null) return '';
    return '${hand.handId}_${hand.state}_${hand.currentPlayerId}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Use select() to only rebuild when specific slices of state change.
    final isMyTurn = ref.watch(
      gameProvider(widget.roomId).select((s) => s.isMyTurn),
    );
    final isLoading = ref.watch(
      gameProvider(widget.roomId).select((s) => s.isLoading),
    );
    final error = ref.watch(
      gameProvider(widget.roomId).select((s) => s.error),
    );
    final hasActiveHand = ref.watch(
      gameProvider(widget.roomId).select((s) => s.currentHand != null),
    );
    final wsConnected = ref.watch(webSocketConnectedProvider);

    // Read the full state only when we need it for child widgets (avoids
    // pulling the entire state into build when only flags changed).
    final gameState = ref.watch(gameProvider(widget.roomId));

    return Listener(
      onPointerDown: (_) => _recordActivity(),
      onPointerMove: (_) => _recordActivity(),
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Game Room',
          style: AppTypography.headline3.copyWith(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          // Connection indicator
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.circle,
              size: 10,
              color: wsConnected ? AppColors.success : AppColors.error,
            ),
          ),
          // Hand history
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.textPrimary),
            tooltip: 'Hand History',
            onPressed: () {
              // TODO: navigate to hand history screen
            },
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textPrimary),
            tooltip: 'Settings',
            onPressed: () {
              // TODO: navigate to room settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ------ Connection status bar ------
          const ConnectionStatusBar(),

          // ------ Error banner ------
          if (error != null) _buildErrorBanner(error),

          // ------ Poker table (expanded) ------
          Expanded(
            child: _buildGameContent(gameState),
          ),

          // ------ My hole cards (below the table, above action panel) ------
          if (gameState.myHoleCards != null &&
              gameState.myHoleCards!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildMyHoleCards(gameState.myHoleCards!),
            ),

          // ------ Turn timer + Action panel (only when it's my turn) ------
          if (isMyTurn) ...[
            TurnTimerBar(
              resetKey: _turnResetKey(gameState),
            ),
            RepaintBoundary(
              child: ActionPanel(
                currentBet: _getCurrentBet(gameState),
                myCurrentBet: _getMyCurrentBet(gameState),
                myChips: _getMyChips(gameState),
                potAmount: _getPotAmount(gameState),
                isProcessing: isLoading,
                onFold: () => _performAction('FOLD'),
                onCheck: () => _performAction('CHECK'),
                onCall: () => _performAction('CALL'),
                onRaise: (amount) => _performAction('RAISE', amount: amount),
                onAllIn: () => _performAction('ALL_IN'),
              ),
            ),
          ],

          // ------ Start hand / auto-start indicator ------
          if (_canStartHand(gameState) && !isMyTurn)
            _buildStartHandArea(gameState),
        ],
      ),
    ),
    );
  }

  // ---------------------------------------------------------------------------
  // Game content with error boundary
  // ---------------------------------------------------------------------------

  Widget _buildGameContent(GameState gameState) {
    // When no active hand and not loading, show an empty state.
    if (gameState.currentHand == null && !gameState.isLoading) {
      return const EmptyState(
        icon: Icons.style_outlined,
        title: 'No active hand',
        subtitle: 'Waiting for the next hand to start.',
      );
    }

    try {
      return Stack(
        children: [
          // Poker table isolated in its own repaint boundary to prevent
          // repaints from overlays (chat, emoji) triggering a full table
          // repaint.
          RepaintBoundary(
            child: PokerTable(
              seats: _buildPlayerSeats(gameState, 6),
              communityCards: _buildCommunityCards(gameState),
              potAmount: gameState.currentHand?.potTotal ?? 0,
              maxPlayers: 6,
            ),
          ),
          // Hand state badge (top center)
          if (gameState.currentHand != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: _buildHandStateBadge(gameState.currentHand!),
              ),
            ),
          // Win probability gauge (top-right corner, only when we have hole cards)
          if (gameState.myHoleCards != null &&
              gameState.myHoleCards!.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: RepaintBoundary(
                child: _buildProbabilityOverlay(),
              ),
            ),
          // Loading overlay
          if (gameState.isLoading)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.chipGold,
                ),
              ),
            ),
          // Emoji overlay -- transparent layer for floating emoji animations.
          // Isolated in a RepaintBoundary so emoji animations don't repaint
          // the poker table or other overlays.
          Positioned.fill(
            child: RepaintBoundary(
              child: EmojiOverlay(
                roomId: widget.roomId,
                maxPlayers: 6,
              ),
            ),
          ),
          // Chat overlay -- positioned at the bottom of the table area.
          // Isolated in a RepaintBoundary since chat messages update
          // independently of the game state.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: ChatOverlay(roomId: widget.roomId),
            ),
          ),
          // Emoji picker toggle button
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showEmojiPicker = !_showEmojiPicker;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Center(
                  child: Text(
                    '\u{1F600}',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ),
          ),
          // Emoji picker panel
          if (_showEmojiPicker)
            Positioned(
              bottom: 56,
              right: 8,
              child: EmojiPicker(
                onEmojiSelected: (emoji) {
                  ref
                      .read(emojiProvider(widget.roomId).notifier)
                      .sendEmoji(emoji);
                },
                onClose: () {
                  setState(() {
                    _showEmojiPicker = false;
                  });
                },
              ),
            ),
        ],
      );
    } catch (e) {
      // Error boundary: if rendering the game content throws, show the error
      // dialog and a fallback message instead of crashing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showErrorDialog(
            context,
            error: e,
            onRetry: () {
              ref.read(gameProvider(widget.roomId).notifier).clearHand();
            },
          );
        }
      });

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error.withOpacity(0.7),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to display game',
              style: AppTypography.body1.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildProbabilityOverlay() {
    final probState = ref.watch(probabilityProvider(widget.roomId));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WinProbabilityGauge(
            winProbability: probState.winProbability,
            isLoading: probState.isLoading,
            size: 64,
          ),
          if (probState.handDistribution.isNotEmpty) ...[
            const SizedBox(height: 4),
            HandStrengthBar(
              handDistribution: probState.handDistribution,
              width: 140,
              barHeight: 6,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return MaterialBanner(
      backgroundColor: AppColors.error.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      content: Text(
        error,
        style: const TextStyle(color: AppColors.error, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Dismiss the error by refreshing or just rebuilding.
            ref.read(gameProvider(widget.roomId).notifier).clearHand();
          },
          child: const Text('DISMISS', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }

  Widget _buildMyHoleCards(List<String> cardCodes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: cardCodes.map((code) {
        try {
          final card = PokerCard.fromCode(code);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: PokerCardWidget(card: card, width: 54, height: 76),
          );
        } catch (_) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: PokerCardWidget(faceDown: true, width: 54, height: 76),
          );
        }
      }).toList(),
    );
  }

  Widget _buildHandStateBadge(GameHand hand) {
    final label = _handStateLabel(hand.state);
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label  #${hand.handNumber}',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _handStateLabel(String state) {
    switch (state) {
      case 'PRE_FLOP':
        return 'Pre-Flop';
      case 'FLOP':
        return 'Flop';
      case 'TURN':
        return 'Turn';
      case 'RIVER':
        return 'River';
      case 'SHOWDOWN':
        return 'Showdown';
      case 'SETTLEMENT':
        return 'Settlement';
      case 'FINISHED':
        return 'Finished';
      default:
        return state;
    }
  }

  Widget _buildStartHandArea(GameState gameState) {
    final isComplete = gameState.currentHand?.isComplete ?? false;
    final hasNoHand = gameState.currentHand == null;

    // Hand just finished → auto-start is scheduled on the server.
    // Show a brief "next hand starting" indicator.
    if (isComplete) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.chipGold,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Next hand starting...',
                style: AppTypography.body2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No hand at all — show manual start button (first hand of the session).
    if (hasNoHand) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: gameState.isLoading ? null : _startHand,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Start Hand',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
