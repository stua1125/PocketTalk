package com.pockettalk.probability;

import com.pockettalk.common.model.HandRank;

import java.util.Map;

public record SimulationResult(
    double winProbability,
    double tieProbability,
    double lossProbability,
    Map<HandRank, Double> handDistribution,
    int simulationCount
) {}
