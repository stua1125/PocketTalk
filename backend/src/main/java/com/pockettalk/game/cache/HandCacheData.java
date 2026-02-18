package com.pockettalk.game.cache;

import java.util.List;
import java.util.UUID;

public record HandCacheData(
    UUID handId,
    UUID roomId,
    long handNumber,
    String state,
    String communityCards,
    long potTotal,
    UUID currentPlayerId,
    List<PlayerCacheData> players
) {}
