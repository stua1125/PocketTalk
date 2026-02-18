package com.pockettalk.chat.service;

import com.pockettalk.auth.entity.User;
import com.pockettalk.auth.repository.UserRepository;
import com.pockettalk.chat.dto.*;
import com.pockettalk.chat.entity.ChatMessage;
import com.pockettalk.chat.repository.ChatMessageRepository;
import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.game.entity.Hand;
import com.pockettalk.game.entity.Room;
import com.pockettalk.game.event.GameEventPublisher;
import com.pockettalk.game.repository.HandRepository;
import com.pockettalk.game.repository.RoomPlayerRepository;
import com.pockettalk.game.repository.RoomRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatMessageRepository chatMessageRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final RoomRepository roomRepository;
    private final UserRepository userRepository;
    private final HandRepository handRepository;
    private final GameEventPublisher eventPublisher;

    /**
     * Send a chat message (persisted to DB + broadcast via WebSocket).
     */
    @Transactional
    public ChatMessageResponse sendMessage(UUID roomId, UUID userId, ChatMessageRequest request) {
        // Validate user is in room
        roomPlayerRepository.findByRoomIdAndUserIdAndStatus(roomId, userId, "ACTIVE")
                .orElseThrow(() -> new BusinessException(
                        "You are not an active player in this room", HttpStatus.FORBIDDEN));

        Room room = roomRepository.findById(roomId)
                .orElseThrow(() -> new BusinessException(
                        "Room not found", HttpStatus.NOT_FOUND));

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(
                        "User not found", HttpStatus.NOT_FOUND));

        // Get current active hand ID if any
        Hand currentHand = handRepository.findTopByRoomIdOrderByHandNumberDesc(roomId)
                .orElse(null);

        String messageType = request.messageType() != null ? request.messageType() : "TEXT";

        ChatMessage message = ChatMessage.builder()
                .room(room)
                .user(user)
                .hand(currentHand)
                .content(request.content())
                .messageType(messageType)
                .build();

        ChatMessage saved = chatMessageRepository.save(message);

        ChatMessageResponse response = ChatMessageResponse.from(saved);

        // Broadcast via WebSocket
        eventPublisher.publishChatToRoom(roomId, response);

        return response;
    }

    /**
     * Get chat history (paginated, newest first).
     */
    @Transactional(readOnly = true)
    public List<ChatMessageResponse> getMessages(UUID roomId, int page, int size) {
        return chatMessageRepository
                .findAllByRoomIdOrderByCreatedAtDesc(roomId, PageRequest.of(page, size))
                .stream()
                .map(ChatMessageResponse::from)
                .toList();
    }

    /**
     * Send an emoji (ephemeral, NOT persisted, just broadcast via WebSocket).
     */
    public void sendEmoji(UUID roomId, UUID userId, EmojiRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(
                        "User not found", HttpStatus.NOT_FOUND));

        EmojiEvent event = new EmojiEvent(
                userId,
                user.getNickname(),
                request.emoji(),
                request.targetUserId(),
                Instant.now()
        );

        eventPublisher.publishEmojiToRoom(roomId, event);
    }
}
