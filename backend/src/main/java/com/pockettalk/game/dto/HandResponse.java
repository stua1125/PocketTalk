package com.pockettalk.game.dto;

import com.pockettalk.common.model.HandState;

import java.util.List;
import java.util.UUID;

public record HandResponse(
    UUID handId,
    UUID roomId,
    long handNumber,
    HandState state,
    List<String> communityCards,
    long potTotal,
    List<HandPlayerResponse> players,
    UUID currentPlayerId,
    List<HandActionResponse> actions
) {}
