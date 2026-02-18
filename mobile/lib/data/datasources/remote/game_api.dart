import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';

/// Dio-based API client for game (hand) endpoints.
///
/// All methods throw [DioException] on network / server errors; callers are
/// expected to handle those at the provider layer.
class GameApi {
  final Dio _dio;

  GameApi(this._dio);

  /// Start a new hand in the given room.
  ///
  /// Returns the initial hand state payload from the server.
  Future<Map<String, dynamic>> startHand(String roomId) async {
    final response = await _dio.post(ApiConstants.handsStart(roomId));
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Fetch the current state of a hand by its ID.
  Future<Map<String, dynamic>> getHand(String handId) async {
    final response = await _dio.get(ApiConstants.hand(handId));
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Submit a player action (FOLD, CHECK, CALL, RAISE, ALL_IN) for a hand.
  ///
  /// [action] should contain at least `{"actionType": "FOLD"}` and optionally
  /// `{"actionType": "RAISE", "amount": 200}`.
  Future<Map<String, dynamic>> processAction(
    String handId,
    Map<String, dynamic> action,
  ) async {
    final response = await _dio.post(
      ApiConstants.handActions(handId),
      data: action,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Retrieve the hand history for a room with pagination.
  Future<List<dynamic>> getHandHistory(
    String roomId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      ApiConstants.roomHands(roomId),
      queryParameters: {'page': page, 'size': size},
    );
    return response.data['data'] as List<dynamic>;
  }
}
