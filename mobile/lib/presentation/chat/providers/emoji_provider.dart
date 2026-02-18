import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/websocket_service.dart';
import '../../game/providers/websocket_provider.dart';

// =============================================================================
// Models
// =============================================================================

/// A single emoji reaction that is currently visible on the overlay.
class ActiveEmoji {
  final String id;
  final String emoji;
  final String senderName;
  final String senderId;
  final int seatNumber;
  final DateTime createdAt;

  const ActiveEmoji({
    required this.id,
    required this.emoji,
    required this.senderName,
    required this.senderId,
    required this.seatNumber,
    required this.createdAt,
  });
}

/// Immutable state for the emoji overlay system.
class EmojiState {
  /// Emojis currently animating on screen.
  final List<ActiveEmoji> activeEmojis;

  const EmojiState({this.activeEmojis = const []});

  EmojiState copyWith({List<ActiveEmoji>? activeEmojis}) {
    return EmojiState(activeEmojis: activeEmojis ?? this.activeEmojis);
  }
}

// =============================================================================
// Notifier
// =============================================================================

class EmojiNotifier extends StateNotifier<EmojiState> {
  final WebSocketService _wsService;
  final String _roomId;

  StreamSubscription<Map<String, dynamic>>? _emojiSub;

  /// Auto-incrementing counter used to generate locally-unique IDs.
  int _idCounter = 0;

  /// Timers keyed by emoji ID for automatic removal after the animation
  /// duration elapses.
  final Map<String, Timer> _removalTimers = {};

  /// Duration that each floating emoji remains in the active list.
  /// Matches the animation duration in [FloatingEmoji].
  static const _displayDuration = Duration(seconds: 3);

  EmojiNotifier(this._wsService, this._roomId) : super(const EmojiState()) {
    _emojiSub = _wsService.emojiEvents.listen(_handleEmojiEvent);
  }

  // ---------------------------------------------------------------------------
  // WebSocket event handling
  // ---------------------------------------------------------------------------

  void _handleEmojiEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final emoji = event['emoji'] as String? ?? '';
    final senderName = event['senderName'] as String? ?? 'Player';
    final senderId = event['senderId'] as String? ?? '';
    final seatNumber = event['seatNumber'] as int? ?? 0;

    if (emoji.isEmpty) return;

    _addEmoji(
      emoji: emoji,
      senderName: senderName,
      senderId: senderId,
      seatNumber: seatNumber,
    );
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Send an emoji reaction over STOMP and optimistically add it to the local
  /// overlay (the server will also broadcast it back, but duplicates are fine
  /// visually since each gets a unique ID).
  void sendEmoji(
    String emoji, {
    String? targetUserId,
    String? senderName,
    String? senderId,
    int? seatNumber,
  }) {
    final payload = <String, dynamic>{
      'emoji': emoji,
      if (targetUserId != null) 'targetUserId': targetUserId,
    };

    _wsService.sendEmoji(_roomId, payload);
  }

  /// Remove a specific emoji from the active list by its [id].
  ///
  /// Called by [FloatingEmoji.onComplete] so the overlay can dispose of the
  /// widget once its animation finishes.
  void removeEmoji(String id) {
    if (!mounted) return;
    _removalTimers[id]?.cancel();
    _removalTimers.remove(id);

    state = state.copyWith(
      activeEmojis:
          state.activeEmojis.where((e) => e.id != id).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _addEmoji({
    required String emoji,
    required String senderName,
    required String senderId,
    required int seatNumber,
  }) {
    final id = 'emoji_${_idCounter++}_${DateTime.now().millisecondsSinceEpoch}';

    final activeEmoji = ActiveEmoji(
      id: id,
      emoji: emoji,
      senderName: senderName,
      senderId: senderId,
      seatNumber: seatNumber,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      activeEmojis: [...state.activeEmojis, activeEmoji],
    );

    // Safety net: auto-remove even if the widget's onComplete never fires
    // (e.g. if the widget is disposed before the animation finishes).
    _removalTimers[id] = Timer(_displayDuration + const Duration(seconds: 1), () {
      removeEmoji(id);
    });
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _emojiSub?.cancel();
    for (final timer in _removalTimers.values) {
      timer.cancel();
    }
    _removalTimers.clear();
    super.dispose();
  }
}

// =============================================================================
// Provider
// =============================================================================

/// Per-room emoji overlay state provider.
///
/// Usage:
/// ```dart
/// final emojiState = ref.watch(emojiProvider(roomId));
/// ref.read(emojiProvider(roomId).notifier).sendEmoji('🎉');
/// ```
final emojiProvider =
    StateNotifierProvider.family<EmojiNotifier, EmojiState, String>(
  (ref, roomId) {
    final wsService = ref.watch(webSocketServiceProvider);
    return EmojiNotifier(wsService, roomId);
  },
);
