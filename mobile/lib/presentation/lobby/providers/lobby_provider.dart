import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/remote/room_api.dart';
import '../../../domain/entities/room.dart';
import '../../auth/providers/auth_provider.dart';

// Room API provider
final roomApiProvider = Provider<RoomApi>((ref) {
  final dio = ref.watch(dioProvider);
  return RoomApi(dio);
});

// Lobby state
class LobbyState {
  final List<Room> rooms;
  final bool isLoading;
  final String? error;

  const LobbyState({
    this.rooms = const [],
    this.isLoading = false,
    this.error,
  });

  LobbyState copyWith({
    List<Room>? rooms,
    bool? isLoading,
    String? error,
  }) {
    return LobbyState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Lobby notifier
class LobbyNotifier extends StateNotifier<LobbyState> {
  final RoomApi _roomApi;

  LobbyNotifier(this._roomApi) : super(const LobbyState());

  Future<void> loadRooms() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _roomApi.getMyRooms();
      final rooms = data
          .map((json) => Room.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(rooms: rooms, isLoading: false);
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? 'Failed to load rooms';
      state = state.copyWith(isLoading: false, error: message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load rooms');
    }
  }

  Future<Room> joinRoom(
    String roomId,
    int seatNumber,
    int buyInAmount,
  ) async {
    try {
      final response = await _roomApi.joinRoom(roomId, {
        'seatNumber': seatNumber,
        'buyInAmount': buyInAmount,
      });
      final roomData = response['data'] as Map<String, dynamic>;
      final room = Room.fromJson(roomData);
      // Refresh the room list after joining
      await loadRooms();
      return room;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? 'Failed to join room';
      throw Exception(message);
    }
  }

  Future<Room> joinByCode(
    String inviteCode,
    int seatNumber,
    int buyInAmount,
  ) async {
    try {
      final response = await _roomApi.joinByCode({
        'inviteCode': inviteCode,
        'seatNumber': seatNumber,
        'buyInAmount': buyInAmount,
      });
      final roomData = response['data'] as Map<String, dynamic>;
      final room = Room.fromJson(roomData);
      // Refresh the room list after joining
      await loadRooms();
      return room;
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ?? 'Failed to join by code';
      throw Exception(message);
    }
  }
}

// Provider
final lobbyProvider = StateNotifierProvider<LobbyNotifier, LobbyState>((ref) {
  return LobbyNotifier(ref.watch(roomApiProvider));
});
