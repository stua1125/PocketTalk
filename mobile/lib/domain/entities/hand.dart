/// Domain entities for a poker hand.
///
/// [GameHand] is the top-level aggregate that holds the full state of a single
/// hand: community cards, pot, player info, and the action log.

class GameHand {
  final String handId;
  final String roomId;
  final int handNumber;
  final String state; // PRE_FLOP, FLOP, TURN, RIVER, SHOWDOWN, SETTLEMENT
  final List<String> communityCards;
  final int potTotal;
  final List<HandPlayerInfo> players;
  final String? currentPlayerId;
  final List<HandActionInfo> actions;

  const GameHand({
    required this.handId,
    required this.roomId,
    required this.handNumber,
    required this.state,
    required this.communityCards,
    required this.potTotal,
    required this.players,
    this.currentPlayerId,
    required this.actions,
  });

  factory GameHand.fromJson(Map<String, dynamic> json) {
    final playersList = json['players'] as List<dynamic>? ?? [];
    final actionsList = json['actions'] as List<dynamic>? ?? [];
    final communityList = json['communityCards'] as List<dynamic>? ?? [];

    return GameHand(
      handId: json['handId'] as String? ?? json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      handNumber: json['handNumber'] as int? ?? 0,
      state: json['state'] as String? ?? 'PRE_FLOP',
      communityCards: communityList.map((c) => c as String).toList(),
      potTotal: json['potTotal'] as int? ?? 0,
      players: playersList
          .map((p) => HandPlayerInfo.fromJson(p as Map<String, dynamic>))
          .toList(),
      currentPlayerId: json['currentPlayerId'] as String?,
      actions: actionsList
          .map((a) => HandActionInfo.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  GameHand copyWith({
    String? handId,
    String? roomId,
    int? handNumber,
    String? state,
    List<String>? communityCards,
    int? potTotal,
    List<HandPlayerInfo>? players,
    String? currentPlayerId,
    List<HandActionInfo>? actions,
  }) {
    return GameHand(
      handId: handId ?? this.handId,
      roomId: roomId ?? this.roomId,
      handNumber: handNumber ?? this.handNumber,
      state: state ?? this.state,
      communityCards: communityCards ?? this.communityCards,
      potTotal: potTotal ?? this.potTotal,
      players: players ?? this.players,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      actions: actions ?? this.actions,
    );
  }

  /// Whether the hand is in a terminal state.
  bool get isComplete =>
      state == 'SHOWDOWN' || state == 'SETTLEMENT' || state == 'FINISHED';
}

class HandPlayerInfo {
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final int seatNumber;
  final int chipCount;
  final String status; // ACTIVE, FOLDED, ALL_IN
  final int betTotal;
  final int wonAmount;
  final List<String>? holeCards; // null if hidden
  final bool isDealer;

  const HandPlayerInfo({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.seatNumber,
    required this.chipCount,
    required this.status,
    required this.betTotal,
    this.wonAmount = 0,
    this.holeCards,
    this.isDealer = false,
  });

  factory HandPlayerInfo.fromJson(Map<String, dynamic> json) {
    final holeCardsList = json['holeCards'] as List<dynamic>?;

    return HandPlayerInfo(
      userId: json['userId'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      seatNumber: json['seatNumber'] as int? ?? 0,
      chipCount: json['chipCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'ACTIVE',
      betTotal: json['betTotal'] as int? ?? 0,
      wonAmount: json['wonAmount'] as int? ?? 0,
      holeCards: holeCardsList?.map((c) => c as String).toList(),
      isDealer: json['isDealer'] as bool? ?? false,
    );
  }

  HandPlayerInfo copyWith({
    String? userId,
    String? nickname,
    String? avatarUrl,
    int? seatNumber,
    int? chipCount,
    String? status,
    int? betTotal,
    int? wonAmount,
    List<String>? holeCards,
    bool? isDealer,
  }) {
    return HandPlayerInfo(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      seatNumber: seatNumber ?? this.seatNumber,
      chipCount: chipCount ?? this.chipCount,
      status: status ?? this.status,
      betTotal: betTotal ?? this.betTotal,
      wonAmount: wonAmount ?? this.wonAmount,
      holeCards: holeCards ?? this.holeCards,
      isDealer: isDealer ?? this.isDealer,
    );
  }
}

class HandActionInfo {
  final String? userId;
  final String actionType;
  final int amount;
  final String handState;
  final int sequenceNum;
  final DateTime? createdAt;

  const HandActionInfo({
    this.userId,
    required this.actionType,
    required this.amount,
    required this.handState,
    required this.sequenceNum,
    this.createdAt,
  });

  factory HandActionInfo.fromJson(Map<String, dynamic> json) {
    return HandActionInfo(
      userId: json['userId'] as String?,
      actionType: json['actionType'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      handState: json['handState'] as String? ?? '',
      sequenceNum: json['sequenceNum'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
