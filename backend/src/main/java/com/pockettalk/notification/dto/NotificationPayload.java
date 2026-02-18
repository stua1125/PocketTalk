package com.pockettalk.notification.dto;

import java.util.Map;
import java.util.UUID;

public record NotificationPayload(
    String type,       // YOUR_TURN, HAND_RESULT, PLAYER_JOINED, PLAYER_LEFT
    String title,
    String body,
    UUID roomId,
    UUID handId,
    Map<String, String> data
) {}
