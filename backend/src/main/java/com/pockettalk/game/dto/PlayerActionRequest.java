package com.pockettalk.game.dto;

import com.pockettalk.common.model.ActionType;
import jakarta.validation.constraints.NotNull;

public record PlayerActionRequest(
    @NotNull ActionType action,
    Long amount
) {}
