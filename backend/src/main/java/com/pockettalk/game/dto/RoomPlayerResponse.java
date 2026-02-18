package com.pockettalk.game.dto;

import com.pockettalk.game.entity.RoomPlayer;

import java.util.UUID;

public record RoomPlayerResponse(
    UUID userId,
    String nickname,
    String avatarUrl,
    int seatNumber,
    long chipCount,
    String status
) {
    public static RoomPlayerResponse from(RoomPlayer rp) {
        return new RoomPlayerResponse(
            rp.getUser().getId(),
            rp.getUser().getNickname(),
            rp.getUser().getAvatarUrl(),
            rp.getSeatNumber(),
            rp.getChipCount(),
            rp.getStatus()
        );
    }
}
