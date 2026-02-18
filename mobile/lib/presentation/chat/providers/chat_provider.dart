import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/chat_api.dart';
import '../../../data/datasources/remote/websocket_service.dart';
import '../../../domain/entities/chat_message.dart';
import '../../auth/providers/auth_provider.dart';
import '../../game/providers/websocket_provider.dart';

// =============================================================================
// Chat state
// =============================================================================

/// Immutable state object for the chat panel.
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    int? unreadCount,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// =============================================================================
// Chat notifier
// =============================================================================

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatApi _chatApi;
  final WebSocketService _wsService;
  final String roomId;
  final String? _myUserId;

  StreamSubscription<Map<String, dynamic>>? _chatSub;

  /// Whether the chat overlay is currently expanded (visible to the user).
  /// When collapsed, incoming messages increment the unread count instead.
  bool _isExpanded = false;

  ChatNotifier(
    this._chatApi,
    this._wsService,
    this.roomId,
    this._myUserId,
  ) : super(const ChatState()) {
    _subscribeToChatStream();
    loadMessages();
  }

  // ---------------------------------------------------------------------------
  // Stream subscription
  // ---------------------------------------------------------------------------

  void _subscribeToChatStream() {
    _chatSub = _wsService.chatMessages.listen(
      _handleChatEvent,
      onError: (e) {
        if (mounted) {
          state = state.copyWith(error: 'Chat stream error');
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Load initial chat history from the REST API.
  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _chatApi.getMessages(roomId);
      final messages = data
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();

      // API returns newest first; we display with newest at the bottom,
      // so reverse the list.
      state = state.copyWith(
        messages: messages.reversed.toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _extractError(e),
      );
    }
  }

  /// Send a chat message.
  ///
  /// Prefers the WebSocket (STOMP) path for real-time delivery. Falls back to
  /// the REST API if the WebSocket is not connected.
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final payload = <String, dynamic>{
      'content': content.trim(),
      'messageType': 'TEXT',
    };

    try {
      if (_wsService.isConnected) {
        _wsService.sendChat(roomId, payload);
      } else {
        // Fallback: REST API
        final data = await _chatApi.sendMessage(roomId, payload);
        final message = ChatMessage.fromJson(data);
        _appendMessage(message);
      }
    } catch (e) {
      state = state.copyWith(error: _extractError(e));
    }
  }

  /// Notify the notifier that the overlay expanded / collapsed so it can
  /// manage the unread badge correctly.
  void setExpanded(bool expanded) {
    _isExpanded = expanded;
    if (expanded) {
      // Clear unread count when the user opens the panel.
      state = state.copyWith(unreadCount: 0);
    }
  }

  // ---------------------------------------------------------------------------
  // WebSocket event handler
  // ---------------------------------------------------------------------------

  void _handleChatEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final message = ChatMessage.fromJson(event);

    _appendMessage(message);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _appendMessage(ChatMessage message) {
    // Avoid duplicates (server may echo our own message via STOMP + REST).
    final isDuplicate = state.messages.any((m) => m.id == message.id);
    if (isDuplicate && message.id.isNotEmpty) return;

    final updated = [...state.messages, message];

    final newUnread = _isExpanded
        ? 0
        : state.unreadCount + (message.userId == _myUserId ? 0 : 1);

    state = state.copyWith(messages: updated, unreadCount: newUnread);
  }

  String _extractError(dynamic e) {
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
    _chatSub?.cancel();
    super.dispose();
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provides the [ChatApi] backed by the application-level [Dio] instance.
final chatApiProvider = Provider<ChatApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatApi(dio);
});

/// Per-room chat state provider.
///
/// Usage:
/// ```dart
/// final chatState = ref.watch(chatProvider(roomId));
/// ref.read(chatProvider(roomId).notifier).sendMessage('Hello!');
/// ```
final chatProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, roomId) {
    final chatApi = ref.watch(chatApiProvider);
    final wsService = ref.watch(webSocketServiceProvider);
    final authState = ref.watch(authProvider);
    final myUserId = authState.user?.id;

    return ChatNotifier(chatApi, wsService, roomId, myUserId);
  },
);
