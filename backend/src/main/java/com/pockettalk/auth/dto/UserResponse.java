package com.pockettalk.auth.dto;

import com.pockettalk.auth.entity.User;
import java.time.Instant;
import java.util.UUID;

public record UserResponse(
    UUID id,
    String email,
    String nickname,
    String avatarUrl,
    Long chipBalance,
    Instant createdAt
) {
    public static UserResponse from(User user) {
        return new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getNickname(),
            user.getAvatarUrl(),
            user.getChipBalance(),
            user.getCreatedAt()
        );
    }
}
