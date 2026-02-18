package com.pockettalk.game.engine;

import com.pockettalk.common.model.Card;
import com.pockettalk.common.model.HandRankResult;
import com.pockettalk.game.entity.HandPlayer;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Resolves the showdown phase of a poker hand.
 *
 * Evaluates each remaining player's hand, determines winners for each pot
 * (including side pots), and handles split pots when hands are tied.
 */
@Component
public class ShowdownResolver {

    private final HandEvaluator handEvaluator;
    private final PotCalculator potCalculator;

    /**
     * Result for a single player at showdown.
     */
    public record ShowdownResult(
            UUID userId,
            HandRankResult handResult,
            long wonAmount
    ) {}

    public ShowdownResolver(HandEvaluator handEvaluator, PotCalculator potCalculator) {
        this.handEvaluator = handEvaluator;
        this.potCalculator = potCalculator;
    }

    /**
     * Resolve the showdown and determine how much each player wins.
     *
     * @param players        the hand players (only non-folded ones should be evaluated)
     * @param communityCards the community cards
     * @param bets           player bets for pot calculation
     * @return list of showdown results with win amounts
     */
    public List<ShowdownResult> resolve(List<HandPlayer> players,
                                         List<Card> communityCards,
                                         List<PotCalculator.PlayerBet> bets) {
        // Evaluate each non-folded player's hand
        Map<UUID, HandRankResult> evaluations = new LinkedHashMap<>();
        List<HandPlayer> eligible = players.stream()
                .filter(p -> !"FOLDED".equals(p.getStatus()))
                .toList();

        for (HandPlayer player : eligible) {
            List<Card> holeCards = parseCards(player.getHoleCards());
            List<Card> allCards = new ArrayList<>(holeCards);
            allCards.addAll(communityCards);

            HandRankResult result = handEvaluator.evaluate(allCards);
            evaluations.put(player.getUser().getId(), result);
        }

        // Calculate pots
        List<PotCalculator.Pot> pots = potCalculator.calculatePots(bets);

        // For each pot, determine winners among eligible players
        Map<UUID, Long> winnings = new LinkedHashMap<>();
        for (UUID userId : evaluations.keySet()) {
            winnings.put(userId, 0L);
        }

        for (PotCalculator.Pot pot : pots) {
            // Find eligible players for this pot who also have evaluations
            Set<UUID> potEligible = pot.eligiblePlayers().stream()
                    .filter(evaluations::containsKey)
                    .collect(Collectors.toSet());

            if (potEligible.isEmpty()) {
                // No one eligible for this pot (all folded) - should not happen normally
                // Distribute to first non-folded player
                if (!evaluations.isEmpty()) {
                    UUID first = evaluations.keySet().iterator().next();
                    winnings.merge(first, pot.amount(), Long::sum);
                }
                continue;
            }

            // Find the best hand among eligible players
            HandRankResult bestHand = potEligible.stream()
                    .map(evaluations::get)
                    .max(Comparator.naturalOrder())
                    .orElseThrow();

            // Find all players with the best hand (for split pot)
            List<UUID> winners = potEligible.stream()
                    .filter(pid -> evaluations.get(pid).score() == bestHand.score())
                    .toList();

            // Split the pot evenly among winners
            long share = pot.amount() / winners.size();
            long remainder = pot.amount() % winners.size();

            for (int i = 0; i < winners.size(); i++) {
                // Give the remainder chip(s) to the first winner(s)
                long amount = share + (i < remainder ? 1 : 0);
                winnings.merge(winners.get(i), amount, Long::sum);
            }
        }

        // Build results
        List<ShowdownResult> results = new ArrayList<>();
        for (Map.Entry<UUID, HandRankResult> entry : evaluations.entrySet()) {
            UUID userId = entry.getKey();
            HandRankResult handResult = entry.getValue();
            long wonAmount = winnings.getOrDefault(userId, 0L);
            results.add(new ShowdownResult(userId, handResult, wonAmount));
        }

        // Sort by won amount descending
        results.sort(Comparator.comparingLong(ShowdownResult::wonAmount).reversed());
        return results;
    }

    /**
     * Parse comma-separated card codes into Card objects.
     */
    private List<Card> parseCards(String cardCodes) {
        if (cardCodes == null || cardCodes.isBlank()) {
            return List.of();
        }
        return Arrays.stream(cardCodes.split(","))
                .map(String::trim)
                .map(Card::fromCode)
                .toList();
    }
}
