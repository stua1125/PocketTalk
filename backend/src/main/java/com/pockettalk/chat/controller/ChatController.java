package com.pockettalk.chat.controller;

import com.pockettalk.chat.dto.ChatMessageRequest;
import com.pockettalk.chat.dto.ChatMessageResponse;
import com.pockettalk.chat.service.ChatService;
import com.pockettalk.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/chat/{roomId}/messages")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ChatMessageResponse> sendMessage(
            @PathVariable UUID roomId,
            @Valid @RequestBody ChatMessageRequest request) {
        UUID userId = getCurrentUserId();
        ChatMessageResponse response = chatService.sendMessage(roomId, userId, request);
        return ApiResponse.ok(response);
    }

    @GetMapping
    public ApiResponse<List<ChatMessageResponse>> getMessages(
            @PathVariable UUID roomId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        List<ChatMessageResponse> messages = chatService.getMessages(roomId, page, size);
        return ApiResponse.ok(messages);
    }

    private UUID getCurrentUserId() {
        return UUID.fromString(
                SecurityContextHolder.getContext().getAuthentication().getName());
    }
}
