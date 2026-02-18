package com.pockettalk.common.model;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class DeckTest {

    private Deck deck;

    @BeforeEach
    void setUp() {
        deck = new Deck();
    }

    // -------------------------------------------------------
    // Full deck has 52 cards
    // -------------------------------------------------------

    @Test
    void newDeck_has52CardsRemaining() {
        assertEquals(52, deck.remaining());
    }

    @Test
    void dealAll52Cards_thenRemainingIsZero() {
        List<Card> all = deck.deal(52);
        assertEquals(52, all.size());
        assertEquals(0, deck.remaining());
    }

    @Test
    void newDeck_containsAllRankSuitCombinations() {
        List<Card> all = deck.deal(52);
        Set<String> codes = new HashSet<>();
        for (Card c : all) {
            codes.add(c.toCode());
        }
        // Every rank x suit combination must be present
        for (Suit suit : Suit.values()) {
            for (Rank rank : Rank.values()) {
                String code = rank.getCode() + suit.getCode();
                assertTrue(codes.contains(code),
                        "Missing card: " + code);
            }
        }
    }

    // -------------------------------------------------------
    // Shuffle produces different order
    // -------------------------------------------------------

    @Test
    void shuffle_producesDifferentOrderFromUnshuffled() {
        // Deal the unshuffled deck to capture the original order
        List<Card> original = new ArrayList<>(deck.deal(52));

        // Create a new deck, shuffle, and deal again
        Deck shuffled = new Deck();
        shuffled.shuffle();
        List<Card> shuffledCards = shuffled.deal(52);

        // It is theoretically possible (but astronomically unlikely) for
        // a shuffled deck to match the original order. We verify they differ.
        assertNotEquals(original, shuffledCards,
                "Shuffled deck should (almost certainly) differ from original order");
    }

    @Test
    void shuffle_resetsDealIndex() {
        deck.deal(10);
        assertEquals(42, deck.remaining());

        deck.shuffle();
        assertEquals(52, deck.remaining());
    }

    // -------------------------------------------------------
    // Deal removes cards
    // -------------------------------------------------------

    @Test
    void dealSingleCard_reducesRemainingByOne() {
        deck.deal();
        assertEquals(51, deck.remaining());
    }

    @Test
    void dealMultipleCards_reducesRemainingCorrectly() {
        deck.deal(5);
        assertEquals(47, deck.remaining());
    }

    @Test
    void dealBeyondDeckSize_throwsException() {
        deck.deal(52);
        assertThrows(IllegalStateException.class, () -> deck.deal());
    }

    @Test
    void dealBatchBeyondDeckSize_throwsException() {
        deck.deal(50);
        assertThrows(IllegalStateException.class, () -> deck.deal(5));
    }

    // -------------------------------------------------------
    // No duplicates after shuffle
    // -------------------------------------------------------

    @Test
    void noDuplicates_afterShuffle() {
        deck.shuffle();
        List<Card> all = deck.deal(52);
        Set<Card> unique = new HashSet<>(all);
        assertEquals(52, unique.size(), "Shuffled deck must have 52 unique cards");
    }

    @Test
    void noDuplicates_afterMultipleShuffles() {
        deck.shuffle();
        deck.shuffle();
        deck.shuffle();
        List<Card> all = deck.deal(52);
        Set<Card> unique = new HashSet<>(all);
        assertEquals(52, unique.size());
    }

    // -------------------------------------------------------
    // removeAll
    // -------------------------------------------------------

    @Test
    void removeAll_reducesCardsInDeck() {
        Card aceOfSpades = Card.fromCode("As");
        Card kingOfHearts = Card.fromCode("Kh");
        deck.removeAll(List.of(aceOfSpades, kingOfHearts));

        assertEquals(50, deck.remaining());

        // Deal all remaining and verify removed cards are absent
        List<Card> remaining = deck.deal(50);
        assertFalse(remaining.contains(aceOfSpades));
        assertFalse(remaining.contains(kingOfHearts));
    }

    @Test
    void removeAll_resetsDealIndex() {
        deck.deal(10); // dealIndex = 10
        assertEquals(42, deck.remaining());

        Card card = Card.fromCode("2h");
        deck.removeAll(List.of(card));
        // removeAll resets dealIndex to 0, and removes 1 card from the underlying list
        // remaining = cards.size() - dealIndex = 51 - 0 = 51
        assertEquals(51, deck.remaining());
    }
}
