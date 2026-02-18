package com.pockettalk.notification.service;

import com.pockettalk.config.RabbitMQConfig;
import com.pockettalk.notification.dto.NotificationPayload;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class NotificationEventPublisher {

    private final RabbitTemplate rabbitTemplate;

    public void publishTurnNotification(UUID userId, UUID roomId, UUID handId) {
        NotificationPayload payload = new NotificationPayload(
            "YOUR_TURN",
            "Your Turn!",
            "It's your turn to act in the poker game",
            roomId,
            handId,
            Map.of("action", "OPEN_GAME")
        );
        publish(userId, payload);
    }

    public void publishHandResult(UUID userId, UUID roomId, UUID handId, long wonAmount) {
        String body = wonAmount > 0 ? "You won " + wonAmount + " chips!" : "Hand completed";
        NotificationPayload payload = new NotificationPayload(
            "HAND_RESULT",
            "Hand Result",
            body,
            roomId,
            handId,
            Map.of()
        );
        publish(userId, payload);
    }

    public void publishPlayerJoined(UUID roomId, UUID excludeUserId, String nickname) {
        NotificationPayload payload = new NotificationPayload(
            "PLAYER_JOINED",
            "Player Joined",
            nickname + " joined the game",
            roomId,
            null,
            Map.of("nickname", nickname)
        );
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.NOTIFICATION_EXCHANGE,
            RabbitMQConfig.NOTIFICATION_ROUTING_KEY,
            Map.of(
                "roomId", roomId.toString(),
                "excludeUserId", excludeUserId.toString(),
                "payload", payload
            )
        );
    }

    public void publishPlayerLeft(UUID roomId, UUID excludeUserId, String nickname) {
        NotificationPayload payload = new NotificationPayload(
            "PLAYER_LEFT",
            "Player Left",
            nickname + " left the game",
            roomId,
            null,
            Map.of("nickname", nickname)
        );
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.NOTIFICATION_EXCHANGE,
            RabbitMQConfig.NOTIFICATION_ROUTING_KEY,
            Map.of(
                "roomId", roomId.toString(),
                "excludeUserId", excludeUserId.toString(),
                "payload", payload
            )
        );
    }

    private void publish(UUID userId, NotificationPayload payload) {
        rabbitTemplate.convertAndSend(
            RabbitMQConfig.NOTIFICATION_EXCHANGE,
            RabbitMQConfig.NOTIFICATION_ROUTING_KEY,
            Map.of("userId", userId.toString(), "payload", payload)
        );
    }
}
