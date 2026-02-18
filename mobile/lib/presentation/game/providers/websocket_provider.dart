import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../data/datasources/local/secure_storage.dart';
import '../../../data/datasources/remote/websocket_service.dart';
import '../../auth/providers/auth_provider.dart';

// =============================================================================
// Core service provider
// =============================================================================

/// Singleton [WebSocketService] that lives for the lifetime of the app.
///
/// Automatically disposed when the provider is no longer watched.
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  ref.onDispose(() => service.dispose());
  return service;
});

// =============================================================================
// Connection management
// =============================================================================

/// Manages the WebSocket connection lifecycle.
///
/// Reads the current auth state and stored JWT to connect/disconnect
/// automatically. Widgets and other providers should use this to ensure the
/// connection is alive before subscribing to streams.
class WebSocketConnectionNotifier extends StateNotifier<WebSocketConnectionState> {
  final WebSocketService _service;
  final SecureStorageService _storage;

  WebSocketConnectionNotifier(this._service, this._storage)
      : super(WebSocketConnectionState.disconnected) {
    // Forward connection-state stream events into this notifier's state.
    _service.connectionState.listen((s) {
      if (mounted) state = s;
    });
  }

  /// Connect to the WebSocket endpoint using the stored JWT.
  ///
  /// No-op if already connected.
  Future<void> connect() async {
    if (_service.isConnected) return;

    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      state = WebSocketConnectionState.disconnected;
      return;
    }

    _service.connect(ApiConstants.baseUrl, token);
  }

  /// Disconnect gracefully.
  void disconnect() {
    _service.disconnect();
    state = WebSocketConnectionState.disconnected;
  }

  /// Reconnect with a fresh token (e.g. after a token refresh).
  Future<void> reconnect() async {
    disconnect();
    await connect();
  }
}

/// Provider for the connection-management notifier.
///
/// Usage:
/// ```dart
/// ref.read(webSocketConnectionProvider.notifier).connect();
/// ```
final webSocketConnectionProvider =
    StateNotifierProvider<WebSocketConnectionNotifier, WebSocketConnectionState>(
  (ref) {
    final service = ref.watch(webSocketServiceProvider);
    final storage = ref.watch(secureStorageProvider);
    final notifier = WebSocketConnectionNotifier(service, storage);

    // Auto-disconnect when the user logs out.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated) {
        notifier.disconnect();
      }
    });

    return notifier;
  },
);

// =============================================================================
// Convenience boolean provider
// =============================================================================

/// Simple boolean that is `true` when the WebSocket is connected.
final webSocketConnectedProvider = Provider<bool>((ref) {
  return ref.watch(webSocketConnectionProvider) ==
      WebSocketConnectionState.connected;
});

// =============================================================================
// Room subscription management
// =============================================================================

/// Manages joining / leaving a specific poker room over WebSocket.
///
/// The [String] family parameter is the room ID.
final roomSubscriptionProvider =
    StateNotifierProvider.family<RoomSubscriptionNotifier, bool, String>(
  (ref, roomId) {
    final service = ref.watch(webSocketServiceProvider);
    final notifier = RoomSubscriptionNotifier(service, roomId);

    ref.onDispose(() {
      service.leaveRoom(roomId);
    });

    return notifier;
  },
);

/// Notifier that tracks whether we are subscribed to a room's topics.
class RoomSubscriptionNotifier extends StateNotifier<bool> {
  final WebSocketService _service;
  final String _roomId;

  RoomSubscriptionNotifier(this._service, this._roomId) : super(false);

  void join() {
    _service.joinRoom(_roomId);
    state = true;
  }

  void leave() {
    _service.leaveRoom(_roomId);
    state = false;
  }
}

// =============================================================================
// Event stream providers
// =============================================================================

/// Game events (hand start, board, showdown, etc.) for a specific room.
///
/// Consumers must ensure the WebSocket is connected and the room is joined
/// before watching this provider.
final gameEventStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, roomId) {
  final service = ref.watch(webSocketServiceProvider);
  return service.gameEvents;
});

/// Chat messages for a specific room.
final chatMessageStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, roomId) {
  final service = ref.watch(webSocketServiceProvider);
  return service.chatMessages;
});

/// Emoji reactions for a specific room (ephemeral, not persisted).
final emojiEventStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, roomId) {
  final service = ref.watch(webSocketServiceProvider);
  return service.emojiEvents;
});

/// Private hole cards for the current user.
final holeCardsStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.holeCards;
});

/// Turn / system notifications for the current user.
final turnNotificationProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.notifications;
});

/// Connection state as a stream for widgets that want to react to transitions.
final connectionStateStreamProvider =
    StreamProvider<WebSocketConnectionState>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.connectionState;
});

// =============================================================================
// Action helpers
// =============================================================================

/// Convenience provider for sending a game action without manually fetching
/// the service.
///
/// Usage:
/// ```dart
/// ref.read(sendGameActionProvider(roomId))({'type': 'FOLD'});
/// ```
final sendGameActionProvider =
    Provider.family<void Function(Map<String, dynamic>), String>(
  (ref, roomId) {
    final service = ref.read(webSocketServiceProvider);
    return (action) => service.sendAction(roomId, action);
  },
);

/// Convenience provider for sending a chat message.
final sendChatMessageProvider =
    Provider.family<void Function(Map<String, dynamic>), String>(
  (ref, roomId) {
    final service = ref.read(webSocketServiceProvider);
    return (message) => service.sendChat(roomId, message);
  },
);

/// Convenience provider for sending an emoji reaction.
final sendEmojiProvider =
    Provider.family<void Function(Map<String, dynamic>), String>(
  (ref, roomId) {
    final service = ref.read(webSocketServiceProvider);
    return (emoji) => service.sendEmoji(roomId, emoji);
  },
);
