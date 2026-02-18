package com.pockettalk.chat.dto;

import com.pockettalk.chat.entity.ChatMessage;

import java.time.Instant;
import java.util.UUID;

public record ChatMessageResponse(
    UUID id,
    UUID userId,
    String nickname,
    String avatarUrl,
    String content,
    String messageType,
    UUID handId,
    Instant createdAt
) {
    public static ChatMessageResponse from(ChatMessage msg) {
        return new ChatMessageResponse(
                msg.getId(),
                msg.getUser().getId(),
                msg.getUser().getNickname(),
                msg.getUser().getAvatarUrl(),
                msg.getContent(),
                msg.getMessageType(),
                msg.getHand() != null ? msg.getHand().getId() : null,
                msg.getCreatedAt()
        );
    }
}
