class Room {
  final String id;
  final String name;
  final String ownerId;
  final String ownerNickname;
  final int maxPlayers;
  final int smallBlind;
  final int bigBlind;
  final int buyInMin;
  final int buyInMax;
  final String status;
  final String? inviteCode;
  final int currentPlayers;
  final int autoStartDelay;
  final List<RoomPlayer> players;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerNickname,
    required this.maxPlayers,
    required this.smallBlind,
    required this.bigBlind,
    required this.buyInMin,
    required this.buyInMax,
    required this.status,
    this.inviteCode,
    required this.currentPlayers,
    this.autoStartDelay = 30,
    required this.players,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final playersList = json['players'] as List<dynamic>? ?? [];
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      ownerNickname: json['ownerNickname'] as String? ?? '',
      maxPlayers: json['maxPlayers'] as int? ?? 6,
      smallBlind: json['smallBlind'] as int? ?? 10,
      bigBlind: json['bigBlind'] as int? ?? 20,
      buyInMin: json['buyInMin'] as int? ?? 100,
      buyInMax: json['buyInMax'] as int? ?? 1000,
      status: json['status'] as String? ?? 'WAITING',
      inviteCode: json['inviteCode'] as String?,
      currentPlayers: json['currentPlayers'] as int? ?? playersList.length,
      autoStartDelay: json['autoStartDelay'] as int? ?? 30,
      players: playersList
          .map((p) => RoomPlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class RoomPlayer {
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final int seatNumber;
  final int chipCount;
  final String status;

  const RoomPlayer({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.seatNumber,
    required this.chipCount,
    required this.status,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      seatNumber: json['seatNumber'] as int? ?? 0,
      chipCount: json['chipCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }
}
