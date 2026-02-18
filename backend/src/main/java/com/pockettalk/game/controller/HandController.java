package com.pockettalk.game.controller;

import com.pockettalk.common.dto.ApiResponse;
import com.pockettalk.game.dto.HandActionResponse;
import com.pockettalk.game.dto.HandResponse;
import com.pockettalk.game.dto.PlayerActionRequest;
import com.pockettalk.game.service.HandService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequiredArgsConstructor
public class HandController {

    private final HandService handService;

    @PostMapping("/api/v1/rooms/{roomId}/hands/start")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<HandResponse> startHand(@PathVariable UUID roomId) {
        UUID userId = getCurrentUserId();
        HandResponse hand = handService.startHand(roomId, userId);
        return ApiResponse.ok(hand);
    }

    @GetMapping("/api/v1/hands/{handId}")
    public ApiResponse<HandResponse> getHand(@PathVariable UUID handId) {
        UUID userId = getCurrentUserId();
        HandResponse hand = handService.getHand(handId, userId);
        return ApiResponse.ok(hand);
    }

    @PostMapping("/api/v1/hands/{handId}/actions")
    public ApiResponse<HandResponse> processAction(
            @PathVariable UUID handId,
            @Valid @RequestBody PlayerActionRequest request) {
        UUID userId = getCurrentUserId();
        HandResponse hand = handService.processAction(handId, userId, request.action(), request.amount());
        return ApiResponse.ok(hand);
    }

    @GetMapping("/api/v1/hands/{handId}/actions")
    public ApiResponse<List<HandActionResponse>> getActions(@PathVariable UUID handId) {
        List<HandActionResponse> actions = handService.getActions(handId);
        return ApiResponse.ok(actions);
    }

    @GetMapping("/api/v1/rooms/{roomId}/hands")
    public ApiResponse<List<HandResponse>> getHandHistory(
            @PathVariable UUID roomId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID userId = getCurrentUserId();
        List<HandResponse> hands = handService.getHandHistory(roomId, userId, page, size);
        return ApiResponse.ok(hands);
    }

    private UUID getCurrentUserId() {
        return UUID.fromString(
                SecurityContextHolder.getContext().getAuthentication().getName());
    }
}
