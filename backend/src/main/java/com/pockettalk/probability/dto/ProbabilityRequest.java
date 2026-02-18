package com.pockettalk.probability.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

public record ProbabilityRequest(
    @NotEmpty @Size(min = 2, max = 2)
    List<String> holeCards,

    @Size(max = 5)
    List<String> communityCards,

    @Min(1) @Max(9)
    int numOpponents
) {
    public ProbabilityRequest {
        if (communityCards == null) {
            communityCards = List.of();
        }
    }
}
