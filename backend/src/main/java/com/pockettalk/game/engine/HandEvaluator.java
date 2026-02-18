package com.pockettalk.game.engine;

import com.pockettalk.common.model.Card;
import com.pockettalk.common.model.HandRank;
import com.pockettalk.common.model.HandRankResult;
import com.pockettalk.common.model.Rank;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Evaluates poker hands, finding the best 5-card hand from up to 7 cards.
 *
 * Score encoding uses the formula:
 *   rank.getValue() * 1_000_000 + sub-scores for kickers/tie-breaking
 *
 * Sub-scores encode card values in descending significance using powers of 15:
 *   first * 15^3 + second * 15^2 + third * 15 + fourth
 *
 * This guarantees correct comparison between any two hands of the same rank
 * while ensuring that a higher HandRank always beats a lower one.
 */
@Component
public class HandEvaluator {

    /**
     * Evaluate the best 5-card hand from the given cards (5 to 7 cards).
     */
    public HandRankResult evaluate(List<Card> cards) {
        if (cards == null || cards.size() < 5 || cards.size() > 7) {
            throw new IllegalArgumentException("Must provide 5 to 7 cards, got: "
                    + (cards == null ? 0 : cards.size()));
        }

        if (cards.size() == 5) {
            return evaluate5(cards);
        }

        // Generate all C(n,5) combinations and find the best
        List<List<Card>> combos = combinations(cards, 5);
        HandRankResult best = null;
        for (List<Card> combo : combos) {
            HandRankResult result = evaluate5(combo);
            if (best == null || result.compareTo(best) > 0) {
                best = result;
            }
        }
        return best;
    }

    /**
     * Evaluate exactly 5 cards as a poker hand.
     */
    private HandRankResult evaluate5(List<Card> cards) {
        List<Card> sorted = cards.stream()
                .sorted(Comparator.comparingInt((Card c) -> c.rank().getValue()).reversed())
                .collect(Collectors.toList());

        boolean isFlush = isFlush(sorted);
        boolean isStraight = isStraight(sorted);
        int straightHighValue = isStraight ? straightHighValue(sorted) : 0;

        // Count ranks
        Map<Rank, Integer> rankCounts = new LinkedHashMap<>();
        for (Card c : sorted) {
            rankCounts.merge(c.rank(), 1, Integer::sum);
        }

        // Sort entries by count desc, then rank value desc
        List<Map.Entry<Rank, Integer>> countEntries = rankCounts.entrySet().stream()
                .sorted(Comparator.<Map.Entry<Rank, Integer>, Integer>comparing(Map.Entry::getValue).reversed()
                        .thenComparing(Comparator.<Map.Entry<Rank, Integer>, Integer>comparing(
                                e -> e.getKey().getValue()).reversed()))
                .toList();

        int topCount = countEntries.get(0).getValue();
        int secondCount = countEntries.size() > 1 ? countEntries.get(1).getValue() : 0;

        // Check hand types from highest to lowest
        if (isFlush && isStraight) {
            if (straightHighValue == Rank.ACE.getValue()) {
                // Royal Flush
                int score = HandRank.ROYAL_FLUSH.getValue() * 1_000_000;
                return new HandRankResult(HandRank.ROYAL_FLUSH, List.copyOf(sorted), score);
            } else {
                // Straight Flush
                int score = HandRank.STRAIGHT_FLUSH.getValue() * 1_000_000 + straightHighValue;
                List<Card> ordered = orderStraight(sorted, straightHighValue);
                return new HandRankResult(HandRank.STRAIGHT_FLUSH, ordered, score);
            }
        }

        if (topCount == 4) {
            // Four of a Kind
            Rank quadRank = countEntries.get(0).getKey();
            Rank kicker = countEntries.get(1).getKey();
            int score = HandRank.FOUR_OF_A_KIND.getValue() * 1_000_000
                    + quadRank.getValue() * 15
                    + kicker.getValue();
            List<Card> ordered = orderByGroups(sorted, countEntries);
            return new HandRankResult(HandRank.FOUR_OF_A_KIND, ordered, score);
        }

        if (topCount == 3 && secondCount == 2) {
            // Full House
            Rank tripRank = countEntries.get(0).getKey();
            Rank pairRank = countEntries.get(1).getKey();
            int score = HandRank.FULL_HOUSE.getValue() * 1_000_000
                    + tripRank.getValue() * 15
                    + pairRank.getValue();
            List<Card> ordered = orderByGroups(sorted, countEntries);
            return new HandRankResult(HandRank.FULL_HOUSE, ordered, score);
        }

        if (isFlush) {
            int score = HandRank.FLUSH.getValue() * 1_000_000
                    + kickerScore(sorted);
            return new HandRankResult(HandRank.FLUSH, List.copyOf(sorted), score);
        }

        if (isStraight) {
            int score = HandRank.STRAIGHT.getValue() * 1_000_000 + straightHighValue;
            List<Card> ordered = orderStraight(sorted, straightHighValue);
            return new HandRankResult(HandRank.STRAIGHT, ordered, score);
        }

        if (topCount == 3) {
            // Three of a Kind
            Rank tripRank = countEntries.get(0).getKey();
            Rank kicker1 = countEntries.get(1).getKey();
            Rank kicker2 = countEntries.get(2).getKey();
            int score = HandRank.THREE_OF_A_KIND.getValue() * 1_000_000
                    + tripRank.getValue() * 15 * 15
                    + kicker1.getValue() * 15
                    + kicker2.getValue();
            List<Card> ordered = orderByGroups(sorted, countEntries);
            return new HandRankResult(HandRank.THREE_OF_A_KIND, ordered, score);
        }

        if (topCount == 2 && secondCount == 2) {
            // Two Pair
            Rank highPair = countEntries.get(0).getKey();
            Rank lowPair = countEntries.get(1).getKey();
            Rank kicker = countEntries.get(2).getKey();
            int score = HandRank.TWO_PAIR.getValue() * 1_000_000
                    + highPair.getValue() * 15 * 15
                    + lowPair.getValue() * 15
                    + kicker.getValue();
            List<Card> ordered = orderByGroups(sorted, countEntries);
            return new HandRankResult(HandRank.TWO_PAIR, ordered, score);
        }

        if (topCount == 2) {
            // One Pair
            Rank pairRank = countEntries.get(0).getKey();
            int score = HandRank.ONE_PAIR.getValue() * 1_000_000
                    + pairRank.getValue() * 15 * 15 * 15;
            int multiplier = 15 * 15;
            for (int i = 1; i < countEntries.size(); i++) {
                score += countEntries.get(i).getKey().getValue() * multiplier;
                multiplier /= 15;
            }
            List<Card> ordered = orderByGroups(sorted, countEntries);
            return new HandRankResult(HandRank.ONE_PAIR, ordered, score);
        }

        // High Card
        int score = HandRank.HIGH_CARD.getValue() * 1_000_000 + kickerScore(sorted);
        return new HandRankResult(HandRank.HIGH_CARD, List.copyOf(sorted), score);
    }

    /**
     * Compute a kicker score from cards sorted high-to-low.
     * Uses base-15 encoding with 5 positions.
     */
    private int kickerScore(List<Card> sorted) {
        int score = 0;
        int multiplier = 15 * 15 * 15 * 15; // 15^4
        for (Card c : sorted) {
            score += c.rank().getValue() * multiplier;
            multiplier /= 15;
        }
        return score;
    }

    /**
     * Check if all 5 cards share the same suit.
     */
    private boolean isFlush(List<Card> cards) {
        return cards.stream().map(Card::suit).distinct().count() == 1;
    }

    /**
     * Check if the 5 cards form a straight (including A-2-3-4-5 wheel).
     */
    private boolean isStraight(List<Card> cards) {
        List<Integer> values = cards.stream()
                .map(c -> c.rank().getValue())
                .sorted(Comparator.reverseOrder())
                .toList();

        // Normal straight check: each card is 1 less than previous
        boolean normal = true;
        for (int i = 1; i < values.size(); i++) {
            if (values.get(i - 1) - values.get(i) != 1) {
                normal = false;
                break;
            }
        }
        if (normal) return true;

        // Wheel: A-2-3-4-5 (values: 14, 5, 4, 3, 2)
        List<Integer> wheel = List.of(14, 5, 4, 3, 2);
        return values.equals(wheel);
    }

    /**
     * Get the high card value of the straight.
     * For the A-2-3-4-5 wheel, the high card is 5.
     */
    private int straightHighValue(List<Card> cards) {
        List<Integer> values = cards.stream()
                .map(c -> c.rank().getValue())
                .sorted(Comparator.reverseOrder())
                .toList();

        // Check for wheel
        List<Integer> wheel = List.of(14, 5, 4, 3, 2);
        if (values.equals(wheel)) {
            return 5; // 5-high straight
        }
        return values.get(0); // highest card
    }

    /**
     * Order cards for a straight, placing them high-to-low.
     * For the wheel (A-2-3-4-5), place 5 first and Ace last.
     */
    private List<Card> orderStraight(List<Card> sorted, int highValue) {
        if (highValue == 5) {
            // Wheel: reorder so Ace is last (acting as 1)
            List<Card> result = new ArrayList<>();
            Card ace = null;
            List<Card> others = new ArrayList<>();
            for (Card c : sorted) {
                if (c.rank() == Rank.ACE) {
                    ace = c;
                } else {
                    others.add(c);
                }
            }
            others.sort(Comparator.comparingInt((Card c) -> c.rank().getValue()).reversed());
            result.addAll(others);
            if (ace != null) result.add(ace);
            return result;
        }
        return List.copyOf(sorted);
    }

    /**
     * Order cards by group size descending, then rank value descending within each group.
     * E.g., for Two Pair (KK-77-3): KK first, then 77, then 3.
     */
    private List<Card> orderByGroups(List<Card> sorted, List<Map.Entry<Rank, Integer>> countEntries) {
        List<Card> result = new ArrayList<>();
        for (Map.Entry<Rank, Integer> entry : countEntries) {
            Rank r = entry.getKey();
            for (Card c : sorted) {
                if (c.rank() == r) {
                    result.add(c);
                }
            }
        }
        return result;
    }

    /**
     * Generate all C(n,k) combinations of the given list.
     */
    private List<List<Card>> combinations(List<Card> cards, int k) {
        List<List<Card>> result = new ArrayList<>();
        combinationsHelper(cards, k, 0, new ArrayList<>(), result);
        return result;
    }

    private void combinationsHelper(List<Card> cards, int k, int start,
                                     List<Card> current, List<List<Card>> result) {
        if (current.size() == k) {
            result.add(new ArrayList<>(current));
            return;
        }
        for (int i = start; i < cards.size(); i++) {
            current.add(cards.get(i));
            combinationsHelper(cards, k, i + 1, current, result);
            current.remove(current.size() - 1);
        }
    }
}
