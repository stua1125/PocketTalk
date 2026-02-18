import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';

class RoomApi {
  final Dio _dio;

  RoomApi(this._dio);

  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> request) async {
    final response = await _dio.post(
      ApiConstants.rooms,
      data: request,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyRooms() async {
    final response = await _dio.get(ApiConstants.rooms);
    final data = response.data as Map<String, dynamic>;
    return data['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getRoom(String roomId) async {
    final response = await _dio.get(ApiConstants.room(roomId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinRoom(
    String roomId,
    Map<String, dynamic> request,
  ) async {
    final response = await _dio.post(
      ApiConstants.roomJoin(roomId),
      data: request,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> leaveRoom(String roomId) async {
    await _dio.post(ApiConstants.roomLeave(roomId));
  }

  Future<Map<String, dynamic>> joinByCode(
    Map<String, dynamic> request,
  ) async {
    final response = await _dio.post(
      ApiConstants.roomJoinByCode,
      data: request,
    );
    return response.data as Map<String, dynamic>;
  }
}
