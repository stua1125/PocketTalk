package com.pockettalk.game.engine;

import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Calculates main pot and side pots for a poker hand.
 *
 * When players go all-in for different amounts, multiple pots are created.
 * Each pot tracks which players are eligible to win it.
 */
@Component
public class PotCalculator {

    /**
     * A player's total bet in the hand.
     */
    public record PlayerBet(UUID userId, long betAmount) {}

    /**
     * A pot with an amount and the set of players eligible to win it.
     */
    public record Pot(long amount, Set<UUID> eligiblePlayers) {}

    /**
     * Calculate pots from the given player bets.
     *
     * Algorithm:
     * 1. Sort bets ascending by amount.
     * 2. Iterate through each unique bet level.
     * 3. At each level, create a pot from the contribution of all players
     *    who bet at least that much (minus what was already allocated to lower pots).
     *
     * @param bets the total bets from each player in the hand
     * @return ordered list of pots, main pot first, then side pots
     */
    public List<Pot> calculatePots(List<PlayerBet> bets) {
        if (bets == null || bets.isEmpty()) {
            return List.of();
        }

        // Filter out zero bets
        List<PlayerBet> nonZero = bets.stream()
                .filter(b -> b.betAmount() > 0)
                .sorted(Comparator.comparingLong(PlayerBet::betAmount))
                .collect(Collectors.toCollection(ArrayList::new));

        if (nonZero.isEmpty()) {
            return List.of();
        }

        List<Pot> pots = new ArrayList<>();
        long previousLevel = 0;

        // Track remaining contributions from each player
        // We iterate through ascending bet levels, collecting contributions
        int i = 0;
        while (i < nonZero.size()) {
            long currentLevel = nonZero.get(i).betAmount();

            if (currentLevel == previousLevel) {
                // This player already fully contributed to previous pots
                i++;
                continue;
            }

            long contribution = currentLevel - previousLevel;

            // All players from index i onward (plus any at this exact level) contribute
            // Actually, ALL remaining players (from i to end) contribute to this pot
            Set<UUID> eligible = new LinkedHashSet<>();
            long potAmount = 0;

            for (int j = i; j < nonZero.size(); j++) {
                eligible.add(nonZero.get(j).userId());
                potAmount += contribution;
            }

            // Also include players before i who had the same level as currentLevel
            // (they're at i already since we sorted and skipped duplicates)

            if (potAmount > 0 && eligible.size() > 0) {
                pots.add(new Pot(potAmount, eligible));
            }

            previousLevel = currentLevel;

            // Advance past all players at this level
            while (i < nonZero.size() && nonZero.get(i).betAmount() == currentLevel) {
                i++;
            }
        }

        return pots;
    }
}
