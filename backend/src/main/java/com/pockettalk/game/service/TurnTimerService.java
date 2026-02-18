package com.pockettalk.game.service;

import com.pockettalk.common.model.ActionType;
import com.pockettalk.common.model.HandState;
import com.pockettalk.game.dto.HandResponse;
import com.pockettalk.game.event.GameEvent;
import com.pockettalk.game.event.GameEventPublisher;
import com.pockettalk.game.event.GameEventType;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.concurrent.*;

/**
 * Manages per-hand turn timers. When a player's turn begins and they do not
 * act within {@link #TURN_TIMEOUT_SECONDS}, they are automatically folded.
 */
@Service
public class TurnTimerService {

    private static final Logger log = LoggerFactory.getLogger(TurnTimerService.class);
    private static final long TURN_TIMEOUT_SECONDS = 10;
    private static final long AFK_FOLD_DELAY_SECONDS = 2;
    private static final long AUTO_START_DELAY_SECONDS = 5;

    private final ScheduledExecutorService scheduler =
            Executors.newSingleThreadScheduledExecutor(r -> {
                Thread t = new Thread(r, "turn-timer");
                t.setDaemon(true);
                return t;
            });

    private final ConcurrentHashMap<UUID, ScheduledFuture<?>> activeTimers = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<UUID, ScheduledFuture<?>> autoStartTimers = new ConcurrentHashMap<>();

    private final HandService handService;
    private final GameEventPublisher eventPublisher;
    private final PlayerPresenceService playerPresenceService;

    public TurnTimerService(@Lazy HandService handService,
                            GameEventPublisher eventPublisher,
                            PlayerPresenceService playerPresenceService) {
        this.handService = handService;
        this.eventPublisher = eventPublisher;
        this.playerPresenceService = playerPresenceService;
    }

    /**
     * Schedule an auto-fold timer for the given hand/player. Any existing
     * timer for this hand is cancelled first.
     *
     * If the player is AFK (no recent heartbeat), fold after a short delay.
     * If the player is active, use the normal turn timeout.
     */
    public void scheduleTurnTimer(UUID handId, UUID playerId, UUID roomId) {
        cancelTimer(handId);

        boolean isActive = playerPresenceService.isActive(roomId, playerId);
        long delay = isActive ? TURN_TIMEOUT_SECONDS : AFK_FOLD_DELAY_SECONDS;

        ScheduledFuture<?> future = scheduler.schedule(
                () -> autoFold(handId, playerId, roomId),
                delay,
                TimeUnit.SECONDS
        );
        activeTimers.put(handId, future);

        if (!isActive) {
            log.info("Player AFK — fast fold in {}s: hand={}, player={}", delay, handId, playerId);
        } else {
            log.debug("Turn timer started: hand={}, player={}, timeout={}s", delay, handId, playerId);
        }
    }

    /**
     * Cancel any pending timer for the given hand.
     */
    public void cancelTimer(UUID handId) {
        ScheduledFuture<?> existing = activeTimers.remove(handId);
        if (existing != null) {
            existing.cancel(false);
        }
    }

    private void autoFold(UUID handId, UUID playerId, UUID roomId) {
        activeTimers.remove(handId);
        log.info("Auto-fold triggered: hand={}, player={}", handId, playerId);

        try {
            // processAction() internally calls scheduleTimerIfNeeded() which
            // handles both the next turn timer and auto-start on settlement.
            HandResponse response = handService.processAction(handId, playerId, ActionType.FOLD, null);

            // Broadcast the auto-fold event to the room.
            eventPublisher.publishToRoom(roomId,
                    GameEvent.of(GameEventType.PLAYER_ACTION, handId, roomId, response));
        } catch (Exception e) {
            log.warn("Auto-fold failed for hand={}, player={}: {}", handId, playerId, e.getMessage());
        }
    }

    /**
     * Schedule auto-start of the next hand after a short delay.
     * Cancels any existing auto-start timer for this room.
     */
    public void scheduleAutoStart(UUID roomId) {
        cancelAutoStart(roomId);

        ScheduledFuture<?> future = scheduler.schedule(
                () -> autoStartHand(roomId),
                AUTO_START_DELAY_SECONDS,
                TimeUnit.SECONDS
        );
        autoStartTimers.put(roomId, future);
        log.info("Auto-start scheduled: room={}, delay={}s", roomId, AUTO_START_DELAY_SECONDS);
    }

    /**
     * Cancel any pending auto-start timer for the given room.
     */
    public void cancelAutoStart(UUID roomId) {
        ScheduledFuture<?> existing = autoStartTimers.remove(roomId);
        if (existing != null) {
            existing.cancel(false);
        }
    }

    private void autoStartHand(UUID roomId) {
        autoStartTimers.remove(roomId);
        log.info("Auto-start triggered: room={}", roomId);

        try {
            HandResponse response = handService.autoStartHand(roomId);

            // Broadcast the new hand event to the room.
            eventPublisher.publishToRoom(roomId,
                    GameEvent.of(GameEventType.HAND_STARTED, response.handId(), roomId, response));

            log.info("Auto-started hand={} in room={}", response.handId(), roomId);
        } catch (Exception e) {
            log.warn("Auto-start failed for room={}: {}", roomId, e.getMessage());
        }
    }

    @PreDestroy
    public void shutdown() {
        scheduler.shutdownNow();
    }
}
