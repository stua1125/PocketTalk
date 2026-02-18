package com.pockettalk.game.event;

import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class GameEventPublisher {

    private final SimpMessagingTemplate messagingTemplate;

    /**
     * Broadcast a game event to all subscribers of the room's game topic.
     */
    public void publishToRoom(UUID roomId, GameEvent event) {
        messagingTemplate.convertAndSend("/topic/room/" + roomId + "/game", event);
    }

    /**
     * Send private hole cards to a specific player via their personal queue.
     */
    public void sendHoleCards(UUID userId, UUID handId, List<String> cards) {
        Map<String, Object> payload = Map.of("handId", handId, "cards", cards);
        messagingTemplate.convertAndSendToUser(
                userId.toString(), "/queue/cards",
                GameEvent.of(GameEventType.HAND_STARTED, handId, null, payload)
        );
    }

    /**
     * Notify a specific player that it is their turn to act.
     */
    public void notifyTurn(UUID userId, UUID handId, UUID roomId) {
        messagingTemplate.convertAndSendToUser(
                userId.toString(), "/queue/notifications",
                GameEvent.of(GameEventType.YOUR_TURN, handId, roomId, null)
        );
    }

    /**
     * Broadcast a chat message to all subscribers of the room's chat topic.
     */
    public void publishChatToRoom(UUID roomId, Object chatMessage) {
        messagingTemplate.convertAndSend("/topic/room/" + roomId + "/chat", chatMessage);
    }

    /**
     * Broadcast an ephemeral emoji reaction to all subscribers of the room's emoji topic.
     */
    public void publishEmojiToRoom(UUID roomId, Object emojiPayload) {
        messagingTemplate.convertAndSend("/topic/room/" + roomId + "/emoji", emojiPayload);
    }
}
