package com.pockettalk.notification.service;

import com.pockettalk.game.entity.RoomPlayer;
import com.pockettalk.game.repository.RoomPlayerRepository;
import com.pockettalk.notification.dto.NotificationPayload;
import com.pockettalk.notification.entity.DeviceToken;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class PushNotificationService {

    private final DeviceTokenService deviceTokenService;
    private final RoomPlayerRepository roomPlayerRepository;

    /**
     * Send push notification to a specific user.
     */
    public void sendToUser(UUID userId, NotificationPayload payload) {
        List<DeviceToken> tokens = deviceTokenService.getActiveTokens(userId);
        for (DeviceToken token : tokens) {
            sendPush(token, payload);
        }
    }

    /**
     * Send push notification to all active players in a room, optionally excluding one user.
     */
    public void sendToRoom(UUID roomId, NotificationPayload payload, UUID excludeUserId) {
        List<RoomPlayer> players = roomPlayerRepository.findAllByRoomIdAndStatus(roomId, "ACTIVE");
        for (RoomPlayer player : players) {
            UUID playerId = player.getUser().getId();
            if (excludeUserId != null && excludeUserId.equals(playerId)) {
                continue;
            }
            sendToUser(playerId, payload);
        }
    }

    private void sendPush(DeviceToken token, NotificationPayload payload) {
        // For MVP: log the push notification
        // TODO: Integrate actual FCM HTTP v1 API
        log.info("PUSH [{}] to user {} ({}): {} - {}",
            payload.type(), token.getUser().getId(), token.getPlatform(),
            payload.title(), payload.body());
    }
}
