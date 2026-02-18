package com.pockettalk.game.dto;

import java.util.List;
import java.util.UUID;

public record HandPlayerResponse(
    UUID userId,
    String nickname,
    int seatNumber,
    long chipCount,
    String status,
    long betTotal,
    long wonAmount,
    List<String> holeCards
) {}
