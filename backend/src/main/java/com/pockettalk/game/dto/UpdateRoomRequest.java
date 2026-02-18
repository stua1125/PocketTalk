package com.pockettalk.game.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record UpdateRoomRequest(
    @Size(min = 2, max = 100) String name,
    @Min(2) @Max(9) Integer maxPlayers,
    @Min(1) Long smallBlind,
    @Min(2) Long bigBlind,
    @Min(1) Long buyInMin,
    @Min(1) Long buyInMax
) {}
