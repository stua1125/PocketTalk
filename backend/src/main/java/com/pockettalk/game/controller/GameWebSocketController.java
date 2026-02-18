package com.pockettalk.game.controller;

import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.game.dto.HandResponse;
import com.pockettalk.game.dto.PlayerActionRequest;
import com.pockettalk.game.entity.Hand;
import com.pockettalk.game.event.GameEvent;
import com.pockettalk.game.event.GameEventPublisher;
import com.pockettalk.game.event.GameEventType;
import com.pockettalk.game.repository.HandRepository;
import com.pockettalk.game.service.HandService;
import com.pockettalk.game.service.PlayerPresenceService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.util.UUID;

@Controller
@RequiredArgsConstructor
public class GameWebSocketController {

    private final HandService handService;
    private final GameEventPublisher eventPublisher;
    private final HandRepository handRepository;
    private final PlayerPresenceService playerPresenceService;

    /**
     * Handle a player action received via WebSocket STOMP.
     * This is an alternative to the REST endpoint for real-time play.
     *
     * Client sends to: /app/room/{roomId}/action
     * Body: PlayerActionRequest (action + optional amount)
     */
    @MessageMapping("/room/{roomId}/action")
    public void handleAction(@DestinationVariable UUID roomId,
                             @Payload PlayerActionRequest request,
                             Principal principal) {
        UUID userId = UUID.fromString(principal.getName());

        // Any action also counts as activity
        playerPresenceService.recordHeartbeat(roomId, userId);

        // Find the active hand for this room
        Hand activeHand = handRepository.findTopByRoomIdOrderByHandNumberDesc(roomId)
                .orElseThrow(() -> new BusinessException("No active hand in room", HttpStatus.BAD_REQUEST, "NO_ACTIVE_HAND"));

        HandResponse hand = handService.processAction(
                activeHand.getId(), userId, request.action(), request.amount());
        eventPublisher.publishToRoom(roomId,
                GameEvent.of(GameEventType.PLAYER_ACTION, hand.handId(), roomId, hand));
    }

    /**
     * Receive a heartbeat ping from a player to indicate they are active.
     * Client sends to: /app/room/{roomId}/heartbeat
     */
    @MessageMapping("/room/{roomId}/heartbeat")
    public void handleHeartbeat(@DestinationVariable UUID roomId, Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        playerPresenceService.recordHeartbeat(roomId, userId);
    }
}
