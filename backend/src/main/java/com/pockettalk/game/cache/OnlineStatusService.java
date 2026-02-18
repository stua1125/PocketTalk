package com.pockettalk.game.cache;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Collections;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class OnlineStatusService {

    private final StringRedisTemplate redisTemplate;

    private static final String ONLINE_KEY_PREFIX = "user:online:";
    private static final String ROOM_ONLINE_KEY = "room:online:";
    private static final Duration ONLINE_TTL = Duration.ofMinutes(5);

    /**
     * Mark user as online (call on WebSocket CONNECT).
     */
    public void setOnline(UUID userId) {
        try {
            String key = ONLINE_KEY_PREFIX + userId;
            redisTemplate.opsForValue().set(key, "1", ONLINE_TTL);
            log.debug("User {} marked online", userId);
        } catch (Exception e) {
            log.warn("Redis unavailable, could not mark user {} online: {}", userId, e.getMessage());
        }
    }

    /**
     * Mark user as offline (call on WebSocket DISCONNECT).
     */
    public void setOffline(UUID userId) {
        try {
            String key = ONLINE_KEY_PREFIX + userId;
            redisTemplate.delete(key);
            log.debug("User {} marked offline", userId);
        } catch (Exception e) {
            log.warn("Redis unavailable, could not mark user {} offline: {}", userId, e.getMessage());
        }
    }

    /**
     * Check if user is online.
     */
    public boolean isOnline(UUID userId) {
        try {
            String key = ONLINE_KEY_PREFIX + userId;
            return Boolean.TRUE.equals(redisTemplate.hasKey(key));
        } catch (Exception e) {
            log.warn("Redis unavailable, assuming user {} is offline: {}", userId, e.getMessage());
            return false;
        }
    }

    /**
     * Add user to room's online set.
     */
    public void joinRoom(UUID userId, UUID roomId) {
        try {
            String key = ROOM_ONLINE_KEY + roomId;
            redisTemplate.opsForSet().add(key, userId.toString());
            log.debug("User {} joined room {} online set", userId, roomId);
        } catch (Exception e) {
            log.warn("Redis unavailable, could not add user {} to room {} online set: {}", userId, roomId, e.getMessage());
        }
    }

    /**
     * Remove user from room's online set.
     */
    public void leaveRoom(UUID userId, UUID roomId) {
        try {
            String key = ROOM_ONLINE_KEY + roomId;
            redisTemplate.opsForSet().remove(key, userId.toString());
            log.debug("User {} left room {} online set", userId, roomId);
        } catch (Exception e) {
            log.warn("Redis unavailable, could not remove user {} from room {} online set: {}", userId, roomId, e.getMessage());
        }
    }

    /**
     * Get online users in a room.
     */
    public Set<String> getOnlineUsersInRoom(UUID roomId) {
        try {
            String key = ROOM_ONLINE_KEY + roomId;
            Set<String> members = redisTemplate.opsForSet().members(key);
            return members != null ? members : Collections.emptySet();
        } catch (Exception e) {
            log.warn("Redis unavailable, returning empty set for room {} online users: {}", roomId, e.getMessage());
            return Collections.emptySet();
        }
    }

    /**
     * Heartbeat: refresh online TTL.
     */
    public void heartbeat(UUID userId) {
        try {
            String key = ONLINE_KEY_PREFIX + userId;
            redisTemplate.expire(key, ONLINE_TTL);
            log.trace("Heartbeat refreshed for user {}", userId);
        } catch (Exception e) {
            log.warn("Redis unavailable, could not refresh heartbeat for user {}: {}", userId, e.getMessage());
        }
    }
}
