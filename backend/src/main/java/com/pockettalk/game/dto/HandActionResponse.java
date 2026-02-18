package com.pockettalk.game.dto;

import com.pockettalk.common.model.ActionType;
import com.pockettalk.common.model.HandState;

import java.time.Instant;
import java.util.UUID;

public record HandActionResponse(
    UUID userId,
    ActionType actionType,
    long amount,
    HandState handState,
    int sequenceNum,
    Instant createdAt
) {}
