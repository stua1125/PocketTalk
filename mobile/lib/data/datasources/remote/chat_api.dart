import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

/// Dio-based API client for chat endpoints.
///
/// All methods throw [DioException] on network / server errors; callers are
/// expected to handle those at the provider layer.
class ChatApi {
  final Dio _dio;

  ChatApi(this._dio);

  /// Send a chat message to the room via the REST API.
  ///
  /// This is the fallback path when the WebSocket is unavailable.
  /// [request] should contain at least `{"content": "Hello"}` and optionally
  /// `{"messageType": "TEXT"}`.
  Future<Map<String, dynamic>> sendMessage(
    String roomId,
    Map<String, dynamic> request,
  ) async {
    final response = await _dio.post(
      ApiConstants.chatMessages(roomId),
      data: request,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Retrieve paginated chat history for a room.
  ///
  /// Returns a list of message JSON objects, newest first (the caller reverses
  /// the order as needed for display).
  Future<List<dynamic>> getMessages(
    String roomId, {
    int page = 0,
    int size = 50,
  }) async {
    final response = await _dio.get(
      ApiConstants.chatMessages(roomId),
      queryParameters: {'page': page, 'size': size},
    );
    return response.data['data'] as List<dynamic>;
  }
}
