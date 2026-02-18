package com.pockettalk.game.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateRoomRequest(
    @NotBlank @Size(min = 1, max = 50) String name,
    @Min(2) @Max(9) int maxPlayers,
    @Min(1) long smallBlind,
    @Min(2) long bigBlind,
    @Min(1) long buyInMin,
    @Min(1) long buyInMax
) {
    public CreateRoomRequest {
        if (maxPlayers == 0) maxPlayers = 6;
        if (smallBlind == 0) smallBlind = 10;
        if (bigBlind == 0) bigBlind = 20;
        if (buyInMin == 0) buyInMin = 400;
        if (buyInMax == 0) buyInMax = 2000;
    }
}
