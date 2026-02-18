package com.pockettalk.chat.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.UUID;

public record EmojiRequest(
    @NotBlank String emoji, // emoji code like "thumbsup", "laugh", "cry"
    UUID targetUserId       // optional: directed at specific player
) {}
