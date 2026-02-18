import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

/// Connection state exposed by [WebSocketService].
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
}

/// Core WebSocket/STOMP service for PocketTalk.
///
/// Manages a single STOMP connection, room-level topic subscriptions,
/// user-specific queue subscriptions, and exposes typed broadcast streams
/// for each event category.
class WebSocketService {
  StompClient? _client;

  /// Active subscriptions keyed by STOMP destination path.
  final Map<String, StompUnsubscribe> _subscriptions = {};

  /// The room currently subscribed to (if any).
  String? _currentRoomId;

  // ---------------------------------------------------------------------------
  // Stream controllers (broadcast so multiple widgets can listen)
  // ---------------------------------------------------------------------------

  final _gameEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatController = StreamController<Map<String, dynamic>>.broadcast();
  final _emojiController = StreamController<Map<String, dynamic>>.broadcast();
  final _holeCardsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController =
      StreamController<WebSocketConnectionState>.broadcast();

  // ---------------------------------------------------------------------------
  // Public streams
  // ---------------------------------------------------------------------------

  /// Game events broadcast to the current room (e.g. hand start, board cards).
  Stream<Map<String, dynamic>> get gameEvents => _gameEventController.stream;

  /// Chat messages broadcast to the current room.
  Stream<Map<String, dynamic>> get chatMessages => _chatController.stream;

  /// Ephemeral emoji reactions broadcast to the current room.
  Stream<Map<String, dynamic>> get emojiEvents => _emojiController.stream;

  /// Private hole cards delivered only to this user.
  Stream<Map<String, dynamic>> get holeCards => _holeCardsController.stream;

  /// Turn and system notifications delivered only to this user.
  Stream<Map<String, dynamic>> get notifications =>
      _notificationController.stream;

  /// Connection lifecycle events.
  Stream<WebSocketConnectionState> get connectionState =>
      _connectionStateController.stream;

  // ---------------------------------------------------------------------------
  // Connection helpers
  // ---------------------------------------------------------------------------

  /// Whether the underlying STOMP client reports a live connection.
  bool get isConnected => _client?.connected ?? false;

  /// The room we are currently subscribed to, or `null`.
  String? get currentRoomId => _currentRoomId;

  // ---------------------------------------------------------------------------
  // Connect / Disconnect
  // ---------------------------------------------------------------------------

  /// Open a STOMP connection to the backend.
  ///
  /// [baseUrl] should be the HTTP base URL (e.g. `http://localhost:8080`).
  /// The method replaces the scheme with `ws://` (or `wss://`) automatically.
  /// [accessToken] is the JWT sent in the STOMP CONNECT frame's
  /// `Authorization` header.
  void connect(String baseUrl, String accessToken) {
    // Avoid double-connecting.
    if (_client?.connected == true) return;

    final wsUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    // SockJS transport URL: the stomp_dart_client expects the raw WebSocket
    // endpoint which, for a Spring SockJS endpoint registered at /ws, is
    // /ws/websocket.
    final url = '$wsUrl/ws/websocket';

    _connectionStateController.add(WebSocketConnectionState.connecting);

    _client = StompClient(
      config: StompConfig(
        url: url,
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onWebSocketError: _onWebSocketError,
        onStompError: _onStompError,
        // The library will automatically attempt reconnection after this delay.
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _client!.activate();
  }

  /// Gracefully disconnect from the server and clean up all subscriptions.
  void disconnect() {
    _unsubscribeAll();
    _currentRoomId = null;
    _client?.deactivate();
    _client = null;
    _connectionStateController.add(WebSocketConnectionState.disconnected);
  }

  // ---------------------------------------------------------------------------
  // Room subscriptions
  // ---------------------------------------------------------------------------

  /// Subscribe to all broadcast topics for [roomId].
  ///
  /// If already subscribed to a different room, the previous room's
  /// subscriptions are removed first (one room at a time).
  void joinRoom(String roomId) {
    if (_currentRoomId == roomId) return;

    // Clean up previous room if any.
    if (_currentRoomId != null) {
      leaveRoom(_currentRoomId!);
    }

    _currentRoomId = roomId;

    _subscribe('/topic/room/$roomId/game', (frame) {
      if (frame.body != null) {
        _gameEventController.add(_decodeBody(frame.body!));
      }
    });

    _subscribe('/topic/room/$roomId/chat', (frame) {
      if (frame.body != null) {
        _chatController.add(_decodeBody(frame.body!));
      }
    });

    _subscribe('/topic/room/$roomId/emoji', (frame) {
      if (frame.body != null) {
        _emojiController.add(_decodeBody(frame.body!));
      }
    });
  }

  /// Unsubscribe from the broadcast topics of [roomId].
  void leaveRoom(String roomId) {
    _unsubscribe('/topic/room/$roomId/game');
    _unsubscribe('/topic/room/$roomId/chat');
    _unsubscribe('/topic/room/$roomId/emoji');

    if (_currentRoomId == roomId) {
      _currentRoomId = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Sending messages
  // ---------------------------------------------------------------------------

  /// Send a player action (fold, call, raise, etc.) to the backend.
  ///
  /// [action] is JSON-serialisable and will be sent to
  /// `/app/room/{roomId}/action`.
  void sendAction(String roomId, Map<String, dynamic> action) {
    if (_client?.connected != true) {
      throw StateError(
        'Cannot send action: WebSocket is not connected.',
      );
    }
    _client!.send(
      destination: '/app/room/$roomId/action',
      body: jsonEncode(action),
    );
  }

  /// Send a chat message to the room.
  void sendChat(String roomId, Map<String, dynamic> message) {
    if (_client?.connected != true) {
      throw StateError(
        'Cannot send chat: WebSocket is not connected.',
      );
    }
    _client!.send(
      destination: '/app/room/$roomId/chat',
      body: jsonEncode(message),
    );
  }

  /// Send an emoji reaction to the room.
  void sendEmoji(String roomId, Map<String, dynamic> emoji) {
    if (_client?.connected != true) {
      throw StateError(
        'Cannot send emoji: WebSocket is not connected.',
      );
    }
    _client!.send(
      destination: '/app/room/$roomId/emoji',
      body: jsonEncode(emoji),
    );
  }

  /// Send a heartbeat ping to the server to indicate the player is active.
  void sendHeartbeat(String roomId) {
    if (_client?.connected != true) return;
    _client!.send(
      destination: '/app/room/$roomId/heartbeat',
      body: '',
    );
  }

  // ---------------------------------------------------------------------------
  // Lifecycle callbacks
  // ---------------------------------------------------------------------------

  void _onConnect(StompFrame frame) {
    _connectionStateController.add(WebSocketConnectionState.connected);

    // Always subscribe to user-specific queues on (re-)connect.
    _subscribeToUserQueues();

    // Re-subscribe to room topics if we were in a room before a reconnect.
    if (_currentRoomId != null) {
      final roomId = _currentRoomId!;
      // Reset so joinRoom doesn't short-circuit.
      _currentRoomId = null;
      joinRoom(roomId);
    }
  }

  void _onDisconnect(StompFrame frame) {
    _subscriptions.clear();
    _connectionStateController.add(WebSocketConnectionState.disconnected);
  }

  void _onWebSocketError(dynamic error) {
    _connectionStateController.add(WebSocketConnectionState.disconnected);
    // Logging -- in production, forward to a logging/crash-reporting service.
    // ignore: avoid_print
    print('[WebSocketService] WebSocket error: $error');
  }

  void _onStompError(StompFrame frame) {
    // ignore: avoid_print
    print('[WebSocketService] STOMP error: ${frame.body}');
  }

  // ---------------------------------------------------------------------------
  // User-specific queues
  // ---------------------------------------------------------------------------

  void _subscribeToUserQueues() {
    _subscribe('/user/queue/cards', (frame) {
      if (frame.body != null) {
        _holeCardsController.add(_decodeBody(frame.body!));
      }
    });

    _subscribe('/user/queue/notifications', (frame) {
      if (frame.body != null) {
        _notificationController.add(_decodeBody(frame.body!));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Internal subscription management
  // ---------------------------------------------------------------------------

  void _subscribe(
    String destination,
    void Function(StompFrame) callback,
  ) {
    // Prevent duplicate subscriptions to the same destination.
    if (_subscriptions.containsKey(destination)) return;

    if (_client?.connected != true) return;

    final unsubscribeFn = _client!.subscribe(
      destination: destination,
      callback: callback,
    );

    _subscriptions[destination] = unsubscribeFn;
  }

  void _unsubscribe(String destination) {
    final unsubscribeFn = _subscriptions.remove(destination);
    if (unsubscribeFn != null) {
      unsubscribeFn(unsubscribeHeaders: {});
    }
  }

  void _unsubscribeAll() {
    for (final unsub in _subscriptions.values) {
      unsub(unsubscribeHeaders: {});
    }
    _subscriptions.clear();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _decodeBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      // If the body isn't valid JSON, wrap it so consumers always get a Map.
      return {'raw': body};
    }
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Disconnect and permanently close all stream controllers.
  ///
  /// After calling [dispose], this instance must not be reused.
  void dispose() {
    disconnect();
    _gameEventController.close();
    _chatController.close();
    _emojiController.close();
    _holeCardsController.close();
    _notificationController.close();
    _connectionStateController.close();
  }
}
