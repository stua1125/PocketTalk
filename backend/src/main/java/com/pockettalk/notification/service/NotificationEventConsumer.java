package com.pockettalk.notification.service;

import com.pockettalk.config.RabbitMQConfig;
import com.pockettalk.notification.dto.NotificationPayload;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationEventConsumer {

    private final PushNotificationService pushNotificationService;

    @RabbitListener(queues = RabbitMQConfig.NOTIFICATION_QUEUE)
    public void handleNotification(Map<String, Object> message) {
        try {
            log.debug("Received notification message: {}", message);

            // Route to user-targeted or room-targeted notification
            if (message.containsKey("userId")) {
                String userId = (String) message.get("userId");
                NotificationPayload payload = extractPayload(message);
                pushNotificationService.sendToUser(UUID.fromString(userId), payload);
            } else if (message.containsKey("roomId")) {
                String roomId = (String) message.get("roomId");
                String excludeUserId = (String) message.get("excludeUserId");
                NotificationPayload payload = extractPayload(message);
                pushNotificationService.sendToRoom(
                    UUID.fromString(roomId),
                    payload,
                    excludeUserId != null ? UUID.fromString(excludeUserId) : null
                );
            } else {
                log.warn("Notification message missing userId or roomId: {}", message);
            }
        } catch (Exception e) {
            log.error("Failed to process notification: {}", e.getMessage(), e);
        }
    }

    @SuppressWarnings("unchecked")
    private NotificationPayload extractPayload(Map<String, Object> message) {
        Object payloadObj = message.get("payload");
        if (payloadObj instanceof Map<?, ?> map) {
            Map<String, Object> payloadMap = (Map<String, Object>) map;
            String roomIdStr = payloadMap.get("roomId") != null ? payloadMap.get("roomId").toString() : null;
            String handIdStr = payloadMap.get("handId") != null ? payloadMap.get("handId").toString() : null;

            Map<String, String> data = Map.of();
            Object dataObj = payloadMap.get("data");
            if (dataObj instanceof Map<?, ?>) {
                data = (Map<String, String>) dataObj;
            }

            return new NotificationPayload(
                (String) payloadMap.get("type"),
                (String) payloadMap.get("title"),
                (String) payloadMap.get("body"),
                roomIdStr != null ? UUID.fromString(roomIdStr) : null,
                handIdStr != null ? UUID.fromString(handIdStr) : null,
                data
            );
        }
        throw new IllegalArgumentException("Invalid payload format in notification message");
    }
}
