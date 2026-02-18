package com.pockettalk.notification.controller;

import com.pockettalk.common.dto.ApiResponse;
import com.pockettalk.notification.dto.RegisterTokenRequest;
import com.pockettalk.notification.service.DeviceTokenService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final DeviceTokenService deviceTokenService;

    @PostMapping("/token")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<Void> registerToken(@Valid @RequestBody RegisterTokenRequest request) {
        UUID userId = getCurrentUserId();
        deviceTokenService.registerToken(userId, request);
        return ApiResponse.ok(null, "Token registered");
    }

    @DeleteMapping("/token/{token}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unregisterToken(@PathVariable String token) {
        UUID userId = getCurrentUserId();
        deviceTokenService.unregisterToken(userId, token);
    }

    private UUID getCurrentUserId() {
        return UUID.fromString(
            SecurityContextHolder.getContext().getAuthentication().getName());
    }
}
