package com.pockettalk.common.model;

public record Card(Rank rank, Suit suit) implements Comparable<Card> {

    /**
     * Parse from 2-char code like "Ah" (Ace of Hearts), "Td" (Ten of Diamonds)
     */
    public static Card fromCode(String code) {
        if (code == null || code.length() != 2) {
            throw new IllegalArgumentException("Card code must be 2 characters: " + code);
        }
        Rank rank = Rank.fromCode(code.substring(0, 1));
        Suit suit = Suit.fromCode(code.substring(1, 2));
        return new Card(rank, suit);
    }

    public String toCode() {
        return rank.getCode() + suit.getCode();
    }

    @Override
    public String toString() {
        return rank.getCode() + suit.getSymbol();
    }

    @Override
    public int compareTo(Card other) {
        return Integer.compare(this.rank.getValue(), other.rank.getValue());
    }
}
