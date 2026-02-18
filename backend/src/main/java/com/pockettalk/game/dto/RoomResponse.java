package com.pockettalk.game.dto;

import com.pockettalk.game.entity.Room;
import com.pockettalk.game.entity.RoomPlayer;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record RoomResponse(
    UUID id,
    String name,
    UUID ownerId,
    String ownerNickname,
    int maxPlayers,
    long smallBlind,
    long bigBlind,
    long buyInMin,
    long buyInMax,
    String status,
    String inviteCode,
    int currentPlayers,
    int autoStartDelay,
    List<RoomPlayerResponse> players,
    Instant createdAt
) {
    public static RoomResponse from(Room room, List<RoomPlayer> players) {
        List<RoomPlayerResponse> playerResponses = players.stream()
            .map(RoomPlayerResponse::from)
            .toList();

        return new RoomResponse(
            room.getId(),
            room.getName(),
            room.getOwner().getId(),
            room.getOwner().getNickname(),
            room.getMaxPlayers(),
            room.getSmallBlind(),
            room.getBigBlind(),
            room.getBuyInMin(),
            room.getBuyInMax(),
            room.getStatus(),
            room.getInviteCode(),
            playerResponses.size(),
            room.getAutoStartDelay(),
            playerResponses,
            room.getCreatedAt()
        );
    }
}
