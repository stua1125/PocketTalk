package com.pockettalk.common.model;

import java.util.List;

public record HandRankResult(
    HandRank rank,
    List<Card> bestFive,
    int score
) implements Comparable<HandRankResult> {
    @Override
    public int compareTo(HandRankResult other) {
        return Integer.compare(this.score, other.score);
    }
}
