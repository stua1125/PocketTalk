package com.pockettalk.notification.dto;

import jakarta.validation.constraints.NotBlank;

public record RegisterTokenRequest(
    @NotBlank String token,
    @NotBlank String platform  // ANDROID or IOS
) {}
