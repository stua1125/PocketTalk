package com.pockettalk.game.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record JoinRoomRequest(
    @Min(-1) @Max(8) int seatNumber,
    @Min(1) long buyInAmount
) {}
