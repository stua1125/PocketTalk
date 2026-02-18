package com.pockettalk.game.cache;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pockettalk.common.model.HandState;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class HandCache {

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    private static final String HAND_KEY_PREFIX = "hand:active:";
    private static final String ROOM_HAND_KEY = "room:active_hand:";
    private static final Duration HAND_TTL = Duration.ofHours(24);

    /**
     * Cache the active hand state for a room.
     */
    public void cacheActiveHand(UUID roomId, UUID handId, HandCacheData data) {
        try {
            String json = objectMapper.writeValueAsString(data);
            String handKey = HAND_KEY_PREFIX + handId;
            String roomKey = ROOM_HAND_KEY + roomId;

            redisTemplate.opsForValue().set(handKey, json, HAND_TTL);
            redisTemplate.opsForValue().set(roomKey, handId.toString(), HAND_TTL);
            log.debug("Cached active hand {} for room {}", handId, roomId);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize hand cache data for hand {}: {}", handId, e.getMessage());
        } catch (Exception e) {
            log.warn("Redis unavailable, skipping hand cache for hand {}: {}", handId, e.getMessage());
        }
    }

    /**
     * Get cached active hand for a room.
     */
    public Optional<HandCacheData> getActiveHand(UUID roomId) {
        try {
            String roomKey = ROOM_HAND_KEY + roomId;
            String handIdStr = redisTemplate.opsForValue().get(roomKey);
            if (handIdStr == null) {
                return Optional.empty();
            }

            String handKey = HAND_KEY_PREFIX + handIdStr;
            String json = redisTemplate.opsForValue().get(handKey);
            if (json == null) {
                return Optional.empty();
            }

            HandCacheData data = objectMapper.readValue(json, HandCacheData.class);
            return Optional.of(data);
        } catch (JsonProcessingException e) {
            log.error("Failed to deserialize hand cache data for room {}: {}", roomId, e.getMessage());
            return Optional.empty();
        } catch (Exception e) {
            log.warn("Redis unavailable, cache miss for room {}: {}", roomId, e.getMessage());
            return Optional.empty();
        }
    }

    /**
     * Update cached hand state (after action).
     */
    public void updateHandState(UUID handId, HandState state, String communityCards, long potTotal) {
        try {
            String handKey = HAND_KEY_PREFIX + handId;
            String json = redisTemplate.opsForValue().get(handKey);
            if (json == null) {
                log.debug("Hand {} not in cache, skipping update", handId);
                return;
            }

            HandCacheData existing = objectMapper.readValue(json, HandCacheData.class);
            HandCacheData updated = new HandCacheData(
                existing.handId(),
                existing.roomId(),
                existing.handNumber(),
                state.name(),
                communityCards,
                potTotal,
                existing.currentPlayerId(),
                existing.players()
            );

            String updatedJson = objectMapper.writeValueAsString(updated);
            redisTemplate.opsForValue().set(handKey, updatedJson, HAND_TTL);
            log.debug("Updated cached hand {} state to {}", handId, state);
        } catch (JsonProcessingException e) {
            log.error("Failed to update hand cache for hand {}: {}", handId, e.getMessage());
        } catch (Exception e) {
            log.warn("Redis unavailable, skipping hand state update for hand {}: {}", handId, e.getMessage());
        }
    }

    /**
     * Remove hand from cache (after settlement).
     */
    public void evictHand(UUID handId, UUID roomId) {
        try {
            String handKey = HAND_KEY_PREFIX + handId;
            String roomKey = ROOM_HAND_KEY + roomId;

            redisTemplate.delete(handKey);
            redisTemplate.delete(roomKey);
            log.debug("Evicted hand {} for room {} from cache", handId, roomId);
        } catch (Exception e) {
            log.warn("Redis unavailable, skipping hand eviction for hand {}: {}", handId, e.getMessage());
        }
    }

    /**
     * Check if a hand is cached.
     */
    public boolean isHandCached(UUID handId) {
        try {
            String handKey = HAND_KEY_PREFIX + handId;
            return Boolean.TRUE.equals(redisTemplate.hasKey(handKey));
        } catch (Exception e) {
            log.warn("Redis unavailable, assuming hand {} is not cached: {}", handId, e.getMessage());
            return false;
        }
    }
}
