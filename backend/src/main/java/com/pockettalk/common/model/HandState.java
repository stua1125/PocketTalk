package com.pockettalk.common.model;

public enum HandState {
    WAITING, PRE_FLOP, FLOP, TURN, RIVER, SHOWDOWN, SETTLEMENT;

    public HandState next() {
        return switch (this) {
            case WAITING -> PRE_FLOP;
            case PRE_FLOP -> FLOP;
            case FLOP -> TURN;
            case TURN -> RIVER;
            case RIVER -> SHOWDOWN;
            case SHOWDOWN -> SETTLEMENT;
            case SETTLEMENT -> WAITING;
        };
    }
}
