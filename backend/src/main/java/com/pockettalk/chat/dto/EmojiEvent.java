package com.pockettalk.chat.dto;

import java.time.Instant;
import java.util.UUID;

public record EmojiEvent(
    UUID senderId,
    String senderNickname,
    String emoji,
    UUID targetUserId,
    Instant timestamp
) {}
