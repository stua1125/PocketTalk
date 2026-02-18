package com.pockettalk.common.model;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class Deck {
    private final List<Card> cards;
    private int dealIndex;

    public Deck() {
        cards = new ArrayList<>(52);
        for (Suit suit : Suit.values()) {
            for (Rank rank : Rank.values()) {
                cards.add(new Card(rank, suit));
            }
        }
        dealIndex = 0;
    }

    public void shuffle() {
        Collections.shuffle(cards, new SecureRandom());
        dealIndex = 0;
    }

    public Card deal() {
        if (dealIndex >= cards.size()) {
            throw new IllegalStateException("No more cards in deck");
        }
        return cards.get(dealIndex++);
    }

    public List<Card> deal(int count) {
        List<Card> dealt = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            dealt.add(deal());
        }
        return dealt;
    }

    public void removeAll(java.util.Collection<Card> cardsToRemove) {
        cards.removeAll(cardsToRemove);
        dealIndex = 0;
    }

    public int remaining() {
        return cards.size() - dealIndex;
    }
}
