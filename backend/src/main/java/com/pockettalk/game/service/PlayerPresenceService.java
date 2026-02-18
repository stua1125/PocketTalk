package com.pockettalk.game.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Tracks player presence (heartbeat) to detect AFK players.
 *
 * Players send periodic heartbeats via WebSocket. If no heartbeat is received
 * within the threshold, the player is considered AFK and will be auto-folded
 * immediately on their turn.
 */
@Service
public class PlayerPresenceService {

    private static final Logger log = LoggerFactory.getLogger(PlayerPresenceService.class);
    private static final long AFK_THRESHOLD_SECONDS = 15;

    private final ConcurrentHashMap<String, Instant> lastActiveMap = new ConcurrentHashMap<>();

    /**
     * Record a heartbeat from a player, marking them as active.
     */
    public void recordHeartbeat(UUID roomId, UUID userId) {
        String key = roomId + ":" + userId;
        lastActiveMap.put(key, Instant.now());
    }

    /**
     * Check if a player is currently active (has sent a heartbeat recently).
     */
    public boolean isActive(UUID roomId, UUID userId) {
        String key = roomId + ":" + userId;
        Instant lastActive = lastActiveMap.get(key);
        if (lastActive == null) {
            return false;
        }
        long secondsSinceLastHeartbeat = Duration.between(lastActive, Instant.now()).getSeconds();
        return secondsSinceLastHeartbeat < AFK_THRESHOLD_SECONDS;
    }

    /**
     * Remove a player's presence record (e.g. when they leave the room).
     */
    public void removePlayer(UUID roomId, UUID userId) {
        lastActiveMap.remove(roomId + ":" + userId);
    }
}
