package com.pockettalk.game.engine;

import com.pockettalk.common.model.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class HandEvaluatorTest {

    private HandEvaluator evaluator;

    @BeforeEach
    void setUp() {
        evaluator = new HandEvaluator();
    }

    // Helper to build a list of cards from short codes like "Ah", "Kd", "Tc"
    private List<Card> cards(String... codes) {
        return java.util.Arrays.stream(codes).map(Card::fromCode).toList();
    }

    // -------------------------------------------------------
    // Royal Flush
    // -------------------------------------------------------
    @Nested
    class RoyalFlush {

        @Test
        void royalFlush_hearts() {
            List<Card> hand = cards("Ah", "Kh", "Qh", "Jh", "Th");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.ROYAL_FLUSH, result.rank());
            assertEquals(5, result.bestFive().size());
        }

        @Test
        void royalFlush_spades() {
            List<Card> hand = cards("As", "Ks", "Qs", "Js", "Ts");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.ROYAL_FLUSH, result.rank());
        }

        @Test
        void royalFlush_from7Cards() {
            List<Card> hand = cards("Ah", "Kh", "Qh", "Jh", "Th", "2c", "3d");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.ROYAL_FLUSH, result.rank());
            assertEquals(5, result.bestFive().size());
        }
    }

    // -------------------------------------------------------
    // Straight Flush
    // -------------------------------------------------------
    @Nested
    class StraightFlushTests {

        @Test
        void straightFlush_9High() {
            List<Card> hand = cards("9d", "8d", "7d", "6d", "5d");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.STRAIGHT_FLUSH, result.rank());
        }

        @Test
        void straightFlush_5High_wheel() {
            // A-2-3-4-5 suited is a straight flush (5-high, not royal)
            List<Card> hand = cards("Ac", "2c", "3c", "4c", "5c");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.STRAIGHT_FLUSH, result.rank());
            // The high value for the wheel is 5 (not Ace)
            // Score = STRAIGHT_FLUSH.value * 1_000_000 + 5
            int expectedScore = HandRank.STRAIGHT_FLUSH.getValue() * 1_000_000 + 5;
            assertEquals(expectedScore, result.score());
        }

        @Test
        void straightFlush_beatsQuads() {
            HandRankResult sf = evaluator.evaluate(cards("9d", "8d", "7d", "6d", "5d"));
            HandRankResult quads = evaluator.evaluate(cards("Ah", "Ad", "Ac", "As", "Kh"));

            assertTrue(sf.compareTo(quads) > 0,
                    "Straight flush must beat four of a kind");
        }

        @Test
        void straightFlush_from7Cards() {
            List<Card> hand = cards("9d", "8d", "7d", "6d", "5d", "Ah", "Kc");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.STRAIGHT_FLUSH, result.rank());
        }
    }

    // -------------------------------------------------------
    // Four of a Kind
    // -------------------------------------------------------
    @Nested
    class FourOfAKindTests {

        @Test
        void fourOfAKind_aces() {
            List<Card> hand = cards("Ah", "Ad", "Ac", "As", "Kh");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FOUR_OF_A_KIND, result.rank());
        }

        @Test
        void fourOfAKind_twos_withAceKicker() {
            List<Card> hand = cards("2h", "2d", "2c", "2s", "Ah");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FOUR_OF_A_KIND, result.rank());
        }

        @Test
        void fourOfAKind_higherQuads_beats_lowerQuads() {
            HandRankResult acesQuads = evaluator.evaluate(cards("Ah", "Ad", "Ac", "As", "2h"));
            HandRankResult kingsQuads = evaluator.evaluate(cards("Kh", "Kd", "Kc", "Ks", "Ah"));

            assertTrue(acesQuads.compareTo(kingsQuads) > 0,
                    "Four aces must beat four kings");
        }

        @Test
        void fourOfAKind_sameQuads_higherKickerWins() {
            HandRankResult quadsAceKicker = evaluator.evaluate(cards("Kh", "Kd", "Kc", "Ks", "Ah"));
            HandRankResult quadsQueenKicker = evaluator.evaluate(cards("Kh", "Kd", "Kc", "Ks", "Qh"));

            assertTrue(quadsAceKicker.compareTo(quadsQueenKicker) > 0,
                    "Same quads with ace kicker must beat queen kicker");
        }

        @Test
        void fourOfAKind_from7Cards() {
            List<Card> hand = cards("Ah", "Ad", "Ac", "As", "Kh", "Qd", "Jc");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FOUR_OF_A_KIND, result.rank());
        }
    }

    // -------------------------------------------------------
    // Full House
    // -------------------------------------------------------
    @Nested
    class FullHouseTests {

        @Test
        void fullHouse_acesOverKings() {
            List<Card> hand = cards("Ah", "Ad", "Ac", "Kh", "Kd");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FULL_HOUSE, result.rank());
        }

        @Test
        void fullHouse_threesOverTwos() {
            List<Card> hand = cards("3h", "3d", "3c", "2h", "2d");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FULL_HOUSE, result.rank());
        }

        @Test
        void fullHouse_higherTrips_wins() {
            HandRankResult acesFullOfTwos = evaluator.evaluate(cards("Ah", "Ad", "Ac", "2h", "2d"));
            HandRankResult kingsFullOfQueens = evaluator.evaluate(cards("Kh", "Kd", "Kc", "Qh", "Qd"));

            assertTrue(acesFullOfTwos.compareTo(kingsFullOfQueens) > 0,
                    "Aces full of twos must beat kings full of queens");
        }

        @Test
        void fullHouse_sameTrips_higherPairWins() {
            HandRankResult acesFullOfKings = evaluator.evaluate(cards("Ah", "Ad", "Ac", "Kh", "Kd"));
            HandRankResult acesFullOfTwos = evaluator.evaluate(cards("Ah", "Ad", "Ac", "2h", "2d"));

            assertTrue(acesFullOfKings.compareTo(acesFullOfTwos) > 0,
                    "Aces full of kings must beat aces full of twos");
        }

        @Test
        void fullHouse_from7Cards() {
            // 7 cards: trip aces + pair kings + two garbage
            List<Card> hand = cards("Ah", "Ad", "Ac", "Kh", "Kd", "3s", "4c");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FULL_HOUSE, result.rank());
        }
    }

    // -------------------------------------------------------
    // Flush
    // -------------------------------------------------------
    @Nested
    class FlushTests {

        @Test
        void flush_aceHigh() {
            List<Card> hand = cards("Ah", "Kh", "9h", "5h", "2h");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FLUSH, result.rank());
        }

        @Test
        void flush_7High() {
            List<Card> hand = cards("7d", "6d", "4d", "3d", "2d");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FLUSH, result.rank());
        }

        @Test
        void flush_higherCards_beats_lowerCards() {
            HandRankResult aceFlush = evaluator.evaluate(cards("Ah", "Kh", "9h", "5h", "2h"));
            HandRankResult kingFlush = evaluator.evaluate(cards("Kd", "Qd", "9d", "5d", "2d"));

            assertTrue(aceFlush.compareTo(kingFlush) > 0);
        }

        @Test
        void flush_sameHighCard_secondKickerDecides() {
            HandRankResult aceKingFlush = evaluator.evaluate(cards("Ah", "Kh", "9h", "5h", "2h"));
            HandRankResult aceQueenFlush = evaluator.evaluate(cards("Ad", "Qd", "9d", "5d", "2d"));

            assertTrue(aceKingFlush.compareTo(aceQueenFlush) > 0);
        }

        @Test
        void flush_from7Cards_bestFlushSelected() {
            // 7 cards with 6 hearts; best 5 should be selected
            List<Card> hand = cards("Ah", "Kh", "Qh", "Jh", "3h", "2c", "4d");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FLUSH, result.rank());
        }
    }

    // -------------------------------------------------------
    // Straight
    // -------------------------------------------------------
    @Nested
    class StraightTests {

        @Test
        void straight_aceHigh() {
            List<Card> hand = cards("Ah", "Kd", "Qc", "Js", "Th");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.STRAIGHT, result.rank());
            // Score should use 14 as the high value
            int expectedScore = HandRank.STRAIGHT.getValue() * 1_000_000 + 14;
            assertEquals(expectedScore, result.score());
        }

        @Test
        void straight_wheel_aceLow() {
            // A-2-3-4-5 (the "wheel") -- ace plays as low
            List<Card> hand = cards("Ah", "2d", "3c", "4s", "5h");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.STRAIGHT, result.rank());
            // Wheel has high value of 5
            int expectedScore = HandRank.STRAIGHT.getValue() * 1_000_000 + 5;
            assertEquals(expectedScore, result.score());
        }

        @Test
        void straight_aceHigh_beats_wheel() {
            HandRankResult aceHigh = evaluator.evaluate(cards("Ah", "Kd", "Qc", "Js", "Th"));
            HandRankResult wheel = evaluator.evaluate(cards("Ac", "2d", "3s", "4h", "5c"));

            assertTrue(aceHigh.compareTo(wheel) > 0,
                    "Ace-high straight must beat ace-low wheel");
        }

        @Test
        void straight_middleRange() {
            List<Card> hand = cards("8h", "7d", "6c", "5s", "4h");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.STRAIGHT, result.rank());
        }

        @Test
        void straight_from7Cards() {
            List<Card> hand = cards("9h", "8d", "7c", "6s", "5h", "Kc", "2d");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.STRAIGHT, result.rank());
        }

        @Test
        void straight_6High_beats_wheel() {
            HandRankResult sixHigh = evaluator.evaluate(cards("6h", "5d", "4c", "3s", "2h"));
            HandRankResult wheel = evaluator.evaluate(cards("Ac", "2d", "3s", "4h", "5c"));

            assertTrue(sixHigh.compareTo(wheel) > 0,
                    "6-high straight must beat 5-high wheel");
        }
    }

    // -------------------------------------------------------
    // Three of a Kind
    // -------------------------------------------------------
    @Nested
    class ThreeOfAKindTests {

        @Test
        void threeOfAKind_aces() {
            List<Card> hand = cards("Ah", "Ad", "Ac", "Kh", "Qd");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.THREE_OF_A_KIND, result.rank());
        }

        @Test
        void threeOfAKind_twos() {
            List<Card> hand = cards("2h", "2d", "2c", "Ah", "Kd");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.THREE_OF_A_KIND, result.rank());
        }

        @Test
        void threeOfAKind_higherTrips_wins() {
            HandRankResult aceTrips = evaluator.evaluate(cards("Ah", "Ad", "Ac", "3h", "2d"));
            HandRankResult kingTrips = evaluator.evaluate(cards("Kh", "Kd", "Kc", "Ah", "Qd"));

            assertTrue(aceTrips.compareTo(kingTrips) > 0);
        }

        @Test
        void threeOfAKind_sameTrips_higherKickerWins() {
            HandRankResult tripsAceKicker = evaluator.evaluate(cards("Kh", "Kd", "Kc", "Ah", "2d"));
            HandRankResult tripsQueenKicker = evaluator.evaluate(cards("Kh", "Kd", "Kc", "Qh", "2d"));

            assertTrue(tripsAceKicker.compareTo(tripsQueenKicker) > 0);
        }
    }

    // -------------------------------------------------------
    // Two Pair
    // -------------------------------------------------------
    @Nested
    class TwoPairTests {

        @Test
        void twoPair_acesAndKings() {
            List<Card> hand = cards("Ah", "Ad", "Kh", "Kd", "Qc");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.TWO_PAIR, result.rank());
        }

        @Test
        void twoPair_higherTopPair_wins() {
            HandRankResult acesAndTwos = evaluator.evaluate(cards("Ah", "Ad", "2h", "2d", "3c"));
            HandRankResult kingsAndQueens = evaluator.evaluate(cards("Kh", "Kd", "Qh", "Qd", "Ac"));

            assertTrue(acesAndTwos.compareTo(kingsAndQueens) > 0,
                    "Aces and twos must beat kings and queens (top pair decides)");
        }

        @Test
        void twoPair_sameTopPair_secondPairDecides() {
            HandRankResult acesAndKings = evaluator.evaluate(cards("Ah", "Ad", "Kh", "Kd", "2c"));
            HandRankResult acesAndTwos = evaluator.evaluate(cards("Ah", "Ad", "2h", "2d", "Kc"));

            assertTrue(acesAndKings.compareTo(acesAndTwos) > 0);
        }

        @Test
        void twoPair_samePairs_kickerDecides() {
            HandRankResult tpAceKicker = evaluator.evaluate(cards("Kh", "Kd", "Qh", "Qd", "Ac"));
            HandRankResult tpTwoKicker = evaluator.evaluate(cards("Kh", "Kd", "Qh", "Qd", "2c"));

            assertTrue(tpAceKicker.compareTo(tpTwoKicker) > 0);
        }
    }

    // -------------------------------------------------------
    // One Pair
    // -------------------------------------------------------
    @Nested
    class OnePairTests {

        @Test
        void onePair_aces() {
            List<Card> hand = cards("Ah", "Ad", "Kh", "Qd", "Jc");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.ONE_PAIR, result.rank());
        }

        @Test
        void onePair_twos() {
            List<Card> hand = cards("2h", "2d", "Ah", "Kd", "Qc");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.ONE_PAIR, result.rank());
        }

        @Test
        void onePair_higherPair_wins() {
            HandRankResult pairAces = evaluator.evaluate(cards("Ah", "Ad", "3h", "4d", "5c"));
            HandRankResult pairKings = evaluator.evaluate(cards("Kh", "Kd", "Ah", "Qd", "Jc"));

            assertTrue(pairAces.compareTo(pairKings) > 0);
        }

        @Test
        void onePair_samePair_kickersDecide() {
            HandRankResult pairKingsAceKicker = evaluator.evaluate(cards("Kh", "Kd", "Ah", "2d", "3c"));
            HandRankResult pairKingsQueenKicker = evaluator.evaluate(cards("Kh", "Kd", "Qh", "2d", "3c"));

            assertTrue(pairKingsAceKicker.compareTo(pairKingsQueenKicker) > 0);
        }
    }

    // -------------------------------------------------------
    // High Card
    // -------------------------------------------------------
    @Nested
    class HighCardTests {

        @Test
        void highCard_aceHigh() {
            List<Card> hand = cards("Ah", "Kd", "9c", "5s", "2h");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.HIGH_CARD, result.rank());
        }

        @Test
        void highCard_7High() {
            List<Card> hand = cards("7h", "5d", "4c", "3s", "2h");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.HIGH_CARD, result.rank());
        }

        @Test
        void highCard_higherCardWins() {
            HandRankResult aceHigh = evaluator.evaluate(cards("Ah", "3d", "4c", "5s", "7h"));
            HandRankResult kingHigh = evaluator.evaluate(cards("Kh", "Qd", "Jc", "Ts", "8h"));

            assertTrue(aceHigh.compareTo(kingHigh) > 0);
        }

        @Test
        void highCard_sameHighCard_secondKickerDecides() {
            HandRankResult aceKing = evaluator.evaluate(cards("Ah", "Kd", "4c", "3s", "2h"));
            HandRankResult aceQueen = evaluator.evaluate(cards("Ad", "Qh", "Jc", "Ts", "9h"));

            assertTrue(aceKing.compareTo(aceQueen) > 0);
        }
    }

    // -------------------------------------------------------
    // Best 5 from 7 card selection
    // -------------------------------------------------------
    @Nested
    class Best5From7Tests {

        @Test
        void best5From7_selectsFlushOverStraight() {
            // 7 cards that contain both a flush and a straight; flush wins
            List<Card> hand = cards("Ah", "Kh", "Qh", "Jh", "2h", "Td", "9c");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FLUSH, result.rank());
        }

        @Test
        void best5From7_selectsFullHouseOverTrips() {
            // Trips + a pair buried among 7 cards
            List<Card> hand = cards("Ah", "Ad", "Ac", "Kh", "Kd", "3s", "4c");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.FULL_HOUSE, result.rank());
        }

        @Test
        void best5From7_selectsBestTwoPair() {
            // Three pairs available in 7 cards; best two pair + best kicker should be selected
            List<Card> hand = cards("Ah", "Ad", "Kh", "Kd", "Qh", "Qd", "2c");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.TWO_PAIR, result.rank());
            // Best two pair should be aces and kings (highest pairs)
            // Score: TWO_PAIR * 1M + Ace(14)*225 + King(13)*15 + Queen(12)
            int expectedScore = HandRank.TWO_PAIR.getValue() * 1_000_000
                    + Rank.ACE.getValue() * 15 * 15
                    + Rank.KING.getValue() * 15
                    + Rank.QUEEN.getValue();
            assertEquals(expectedScore, result.score());
        }

        @Test
        void best5From7_holdemExample() {
            // Player has 7h Kd, board is Ah Kh Qs 7c 2d
            // Best hand: pair of kings with A, Q, 7 kickers
            List<Card> hand = cards("7h", "Kd", "Ah", "Kh", "Qs", "7c", "2d");
            HandRankResult result = evaluator.evaluate(hand);

            assertEquals(HandRank.TWO_PAIR, result.rank());
        }
    }

    // -------------------------------------------------------
    // Tie-breaking between same rank hands (kickers)
    // -------------------------------------------------------
    @Nested
    class TieBreakingTests {

        @Test
        void exactSameHand_scoresEqual() {
            // Same ranks, different suits -- scores should be equal
            HandRankResult hand1 = evaluator.evaluate(cards("Ah", "Kd", "Qc", "Js", "9h"));
            HandRankResult hand2 = evaluator.evaluate(cards("Ad", "Kh", "Qh", "Jc", "9d"));

            assertEquals(hand1.score(), hand2.score());
        }

        @Test
        void flush_exactSameRanks_scoresEqual() {
            HandRankResult flush1 = evaluator.evaluate(cards("Ah", "Kh", "9h", "5h", "2h"));
            HandRankResult flush2 = evaluator.evaluate(cards("Ad", "Kd", "9d", "5d", "2d"));

            assertEquals(flush1.score(), flush2.score());
        }

        @Test
        void fullHouse_differentPairs_tiebreak() {
            HandRankResult fhKings = evaluator.evaluate(cards("Ah", "Ad", "Ac", "Kh", "Kd"));
            HandRankResult fhQueens = evaluator.evaluate(cards("Ah", "Ad", "Ac", "Qh", "Qd"));

            assertTrue(fhKings.compareTo(fhQueens) > 0,
                    "Same trips, higher pair should win");
        }
    }

    // -------------------------------------------------------
    // Edge cases
    // -------------------------------------------------------
    @Nested
    class EdgeCaseTests {

        @Test
        void aceHighStraight_vs_aceLowStraight() {
            HandRankResult aceHigh = evaluator.evaluate(cards("Ah", "Kd", "Qc", "Js", "Th"));
            HandRankResult aceLow = evaluator.evaluate(cards("Ac", "2d", "3s", "4h", "5c"));

            assertTrue(aceHigh.compareTo(aceLow) > 0,
                    "A-K-Q-J-T straight must beat A-2-3-4-5 wheel");
            assertEquals(HandRank.STRAIGHT, aceHigh.rank());
            assertEquals(HandRank.STRAIGHT, aceLow.rank());
        }

        @Test
        void nullInput_throws() {
            assertThrows(IllegalArgumentException.class, () -> evaluator.evaluate(null));
        }

        @Test
        void fewerThan5Cards_throws() {
            assertThrows(IllegalArgumentException.class,
                    () -> evaluator.evaluate(cards("Ah", "Kd", "Qc", "Js")));
        }

        @Test
        void moreThan7Cards_throws() {
            assertThrows(IllegalArgumentException.class,
                    () -> evaluator.evaluate(cards("Ah", "Kd", "Qc", "Js", "Th", "9h", "8h", "7h")));
        }

        @Test
        void handRankOrdering_isCorrect() {
            HandRankResult royalFlush = evaluator.evaluate(cards("Ah", "Kh", "Qh", "Jh", "Th"));
            HandRankResult straightFlush = evaluator.evaluate(cards("9d", "8d", "7d", "6d", "5d"));
            HandRankResult quads = evaluator.evaluate(cards("Ah", "Ad", "Ac", "As", "Kh"));
            HandRankResult fullHouse = evaluator.evaluate(cards("Ah", "Ad", "Ac", "Kh", "Kd"));
            HandRankResult flush = evaluator.evaluate(cards("Ah", "Qh", "9h", "5h", "2h"));
            HandRankResult straight = evaluator.evaluate(cards("Ah", "Kd", "Qc", "Js", "Th"));
            HandRankResult trips = evaluator.evaluate(cards("Ah", "Ad", "Ac", "Kh", "Qd"));
            HandRankResult twoPair = evaluator.evaluate(cards("Ah", "Ad", "Kh", "Kd", "Qc"));
            HandRankResult onePair = evaluator.evaluate(cards("Ah", "Ad", "Kh", "Qd", "Jc"));
            HandRankResult highCard = evaluator.evaluate(cards("Ah", "Kd", "Qc", "Js", "9h"));

            assertTrue(royalFlush.compareTo(straightFlush) > 0);
            assertTrue(straightFlush.compareTo(quads) > 0);
            assertTrue(quads.compareTo(fullHouse) > 0);
            assertTrue(fullHouse.compareTo(flush) > 0);
            assertTrue(flush.compareTo(straight) > 0);
            assertTrue(straight.compareTo(trips) > 0);
            assertTrue(trips.compareTo(twoPair) > 0);
            assertTrue(twoPair.compareTo(onePair) > 0);
            assertTrue(onePair.compareTo(highCard) > 0);
        }
    }
}
