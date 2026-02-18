package com.pockettalk.common.model;

public enum Rank {
    TWO("2", 2), THREE("3", 3), FOUR("4", 4), FIVE("5", 5),
    SIX("6", 6), SEVEN("7", 7), EIGHT("8", 8), NINE("9", 9),
    TEN("T", 10), JACK("J", 11), QUEEN("Q", 12), KING("K", 13), ACE("A", 14);

    private final String code;
    private final int value;

    Rank(String code, int value) {
        this.code = code;
        this.value = value;
    }

    public String getCode() { return code; }
    public int getValue() { return value; }

    public static Rank fromCode(String code) {
        for (Rank rank : values()) {
            if (rank.code.equalsIgnoreCase(code)) return rank;
        }
        throw new IllegalArgumentException("Unknown rank code: " + code);
    }
}
