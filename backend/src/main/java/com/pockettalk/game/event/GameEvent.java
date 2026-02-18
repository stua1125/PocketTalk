package com.pockettalk.game.event;

import java.time.Instant;
import java.util.UUID;

public record GameEvent(
    GameEventType type,
    UUID handId,
    UUID roomId,
    Object payload,
    Instant timestamp
) {
    public static GameEvent of(GameEventType type, UUID handId, UUID roomId, Object payload) {
        return new GameEvent(type, handId, roomId, payload, Instant.now());
    }
}
