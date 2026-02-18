package com.pockettalk.probability;

import com.pockettalk.common.model.Card;
import com.pockettalk.common.model.Deck;
import com.pockettalk.common.model.HandRank;
import com.pockettalk.common.model.HandRankResult;
import com.pockettalk.game.engine.HandEvaluator;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.*;

/**
 * Monte Carlo simulation engine for estimating poker hand probabilities.
 *
 * For each trial the simulator removes the known cards (hole + community) from
 * a fresh deck, shuffles, deals the remaining community cards and opponent
 * hole cards, evaluates every hand, and tallies wins / ties / losses for the
 * hero player.
 */
@Component
@RequiredArgsConstructor
public class MonteCarloSimulator {

    private static final int DEFAULT_SIMULATIONS = 10_000;

    private final HandEvaluator handEvaluator;

    /**
     * Run a Monte Carlo simulation with the default number of trials (10,000).
     */
    public SimulationResult simulate(List<Card> holeCards, List<Card> communityCards, int numOpponents) {
        return simulate(holeCards, communityCards, numOpponents, DEFAULT_SIMULATIONS);
    }

    /**
     * Run a Monte Carlo simulation.
     *
     * @param holeCards      the hero's 2 hole cards
     * @param communityCards the known community cards (0-5)
     * @param numOpponents   number of opponents (1-9)
     * @param simulations    number of simulation trials to run
     * @return aggregated simulation results
     */
    public SimulationResult simulate(List<Card> holeCards, List<Card> communityCards,
                                     int numOpponents, int simulations) {
        int wins = 0;
        int ties = 0;
        int losses = 0;
        Map<HandRank, Integer> handCounts = new EnumMap<>(HandRank.class);
        for (HandRank hr : HandRank.values()) {
            handCounts.put(hr, 0);
        }

        // Cards that are already known and must be excluded from the deck
        Set<Card> knownCards = new HashSet<>(holeCards);
        knownCards.addAll(communityCards);

        int communityNeeded = 5 - communityCards.size();

        for (int i = 0; i < simulations; i++) {
            // Build a fresh deck, remove known cards, and shuffle
            Deck deck = new Deck();
            deck.removeAll(knownCards);
            deck.shuffle();

            // Deal the remaining community cards for this trial
            List<Card> trialCommunity = new ArrayList<>(communityCards);
            for (int c = 0; c < communityNeeded; c++) {
                trialCommunity.add(deck.deal());
            }

            // Evaluate the hero's hand (hole cards + full community)
            List<Card> heroCards = new ArrayList<>(holeCards);
            heroCards.addAll(trialCommunity);
            HandRankResult heroResult = handEvaluator.evaluate(heroCards);

            // Track hand distribution for the hero
            handCounts.merge(heroResult.rank(), 1, Integer::sum);

            // Evaluate each opponent's hand and find the best one
            HandRankResult bestOpponent = null;
            for (int opp = 0; opp < numOpponents; opp++) {
                List<Card> oppCards = new ArrayList<>(2);
                oppCards.add(deck.deal());
                oppCards.add(deck.deal());
                oppCards.addAll(trialCommunity);

                HandRankResult oppResult = handEvaluator.evaluate(oppCards);
                if (bestOpponent == null || oppResult.compareTo(bestOpponent) > 0) {
                    bestOpponent = oppResult;
                }
            }

            // Compare hero against best opponent
            int cmp = heroResult.compareTo(bestOpponent);
            if (cmp > 0) {
                wins++;
            } else if (cmp == 0) {
                ties++;
            } else {
                losses++;
            }
        }

        // Build probability maps
        double total = simulations;
        Map<HandRank, Double> handDistribution = new EnumMap<>(HandRank.class);
        for (Map.Entry<HandRank, Integer> entry : handCounts.entrySet()) {
            handDistribution.put(entry.getKey(), entry.getValue() / total);
        }

        return new SimulationResult(
                wins / total,
                ties / total,
                losses / total,
                handDistribution,
                simulations
        );
    }
}
