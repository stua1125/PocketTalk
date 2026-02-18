package com.pockettalk.probability.dto;

import java.util.Map;

public record ProbabilityResponse(
    double winProbability,
    double tieProbability,
    double lossProbability,
    Map<String, Double> handDistribution,
    int simulationCount
) {}
