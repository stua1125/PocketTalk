package com.pockettalk.chat.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChatMessageRequest(
    @NotBlank @Size(max = 500) String content,
    String messageType // TEXT or EMOJI, defaults to TEXT
) {}
