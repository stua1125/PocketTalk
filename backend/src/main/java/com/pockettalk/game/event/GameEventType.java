package com.pockettalk.game.event;

public enum GameEventType {
    HAND_STARTED,       // New hand started
    PLAYER_ACTION,      // A player took an action
    STATE_CHANGED,      // Hand state changed (FLOP, TURN, RIVER)
    COMMUNITY_CARDS,    // Community cards dealt
    SHOWDOWN,           // Showdown results
    HAND_SETTLED,       // Hand completed and chips distributed
    PLAYER_JOINED,      // Player joined room
    PLAYER_LEFT,        // Player left room
    YOUR_TURN           // Notification to specific player
}
