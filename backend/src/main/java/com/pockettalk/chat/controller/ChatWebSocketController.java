package com.pockettalk.chat.controller;

import com.pockettalk.chat.dto.ChatMessageRequest;
import com.pockettalk.chat.dto.EmojiRequest;
import com.pockettalk.chat.service.ChatService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.util.UUID;

@Controller
@RequiredArgsConstructor
public class ChatWebSocketController {

    private final ChatService chatService;

    @MessageMapping("/room/{roomId}/chat")
    public void handleChatMessage(@DestinationVariable UUID roomId,
                                   @Payload ChatMessageRequest request,
                                   Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.sendMessage(roomId, userId, request);
    }

    @MessageMapping("/room/{roomId}/emoji")
    public void handleEmoji(@DestinationVariable UUID roomId,
                             @Payload EmojiRequest request,
                             Principal principal) {
        UUID userId = UUID.fromString(principal.getName());
        chatService.sendEmoji(roomId, userId, request);
    }
}
