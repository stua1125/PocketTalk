package com.pockettalk.game.cache;

import java.util.UUID;

public record PlayerCacheData(
    UUID userId,
    int seatNumber,
    String status,
    long chipCount,
    long betTotal
) {}
