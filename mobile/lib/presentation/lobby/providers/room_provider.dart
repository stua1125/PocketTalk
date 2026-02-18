import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/remote/room_api.dart';
import '../../../domain/entities/room.dart';
import 'lobby_provider.dart';

// Create Room State
class CreateRoomState {
  final bool isLoading;
  final String? error;
  final Room? createdRoom;

  const CreateRoomState({
    this.isLoading = false,
    this.error,
    this.createdRoom,
  });

  CreateRoomState copyWith({
    bool? isLoading,
    String? error,
    Room? createdRoom,
  }) {
    return CreateRoomState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      createdRoom: createdRoom,
    );
  }
}

// Create Room Notifier
class CreateRoomNotifier extends StateNotifier<CreateRoomState> {
  final RoomApi _roomApi;

  CreateRoomNotifier(this._roomApi) : super(const CreateRoomState());

  Future<void> createRoom({
    required String name,
    required int maxPlayers,
    required int smallBlind,
    required int bigBlind,
    required int buyInMin,
    required int buyInMax,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _roomApi.createRoom({
        'name': name,
        'maxPlayers': maxPlayers,
        'smallBlind': smallBlind,
        'bigBlind': bigBlind,
        'buyInMin': buyInMin,
        'buyInMax': buyInMax,
      });
      final roomData = response['data'] as Map<String, dynamic>;
      final room = Room.fromJson(roomData);
      state = CreateRoomState(createdRoom: room);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to create room';
      state = CreateRoomState(error: message);
    }
  }

  void reset() {
    state = const CreateRoomState();
  }
}

// Provider
final createRoomProvider =
    StateNotifierProvider<CreateRoomNotifier, CreateRoomState>((ref) {
  return CreateRoomNotifier(ref.read(roomApiProvider));
});

// Join Room State
class JoinRoomState {
  final bool isLoading;
  final String? error;
  final Room? joinedRoom;

  const JoinRoomState({
    this.isLoading = false,
    this.error,
    this.joinedRoom,
  });

  JoinRoomState copyWith({
    bool? isLoading,
    String? error,
    Room? joinedRoom,
  }) {
    return JoinRoomState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      joinedRoom: joinedRoom,
    );
  }
}

// Join Room Notifier
class JoinRoomNotifier extends StateNotifier<JoinRoomState> {
  final RoomApi _roomApi;

  JoinRoomNotifier(this._roomApi) : super(const JoinRoomState());

  Future<void> joinRoom({
    required String roomId,
    required int seatNumber,
    required int buyInAmount,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _roomApi.joinRoom(roomId, {
        'seatNumber': seatNumber,
        'buyInAmount': buyInAmount,
      });
      final roomData = response['data'] as Map<String, dynamic>;
      final room = Room.fromJson(roomData);
      state = JoinRoomState(joinedRoom: room);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] ?? 'Failed to join room';
      state = JoinRoomState(error: message);
    }
  }

  Future<void> joinByCode({
    required String inviteCode,
    required int seatNumber,
    required int buyInAmount,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _roomApi.joinByCode({
        'inviteCode': inviteCode,
        'seatNumber': seatNumber,
        'buyInAmount': buyInAmount,
      });
      final roomData = response['data'] as Map<String, dynamic>;
      final room = Room.fromJson(roomData);
      state = JoinRoomState(joinedRoom: room);
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] ?? 'Failed to join room by code';
      state = JoinRoomState(error: message);
    }
  }

  void reset() {
    state = const JoinRoomState();
  }
}

// Provider
final joinRoomProvider =
    StateNotifierProvider<JoinRoomNotifier, JoinRoomState>((ref) {
  return JoinRoomNotifier(ref.read(roomApiProvider));
});
