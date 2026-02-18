package com.pockettalk.notification.service;

import com.pockettalk.auth.entity.User;
import com.pockettalk.auth.repository.UserRepository;
import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.notification.dto.RegisterTokenRequest;
import com.pockettalk.notification.entity.DeviceToken;
import com.pockettalk.notification.repository.DeviceTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class DeviceTokenService {

    private final DeviceTokenRepository deviceTokenRepository;
    private final UserRepository userRepository;

    @Transactional
    public void registerToken(UUID userId, RegisterTokenRequest request) {
        Optional<DeviceToken> existing = deviceTokenRepository.findByUserIdAndToken(userId, request.token());

        if (existing.isPresent()) {
            DeviceToken token = existing.get();
            token.setActive(true);
            token.setPlatform(request.platform());
            deviceTokenRepository.save(token);
        } else {
            User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("User not found", HttpStatus.NOT_FOUND));

            DeviceToken token = DeviceToken.builder()
                .user(user)
                .token(request.token())
                .platform(request.platform())
                .isActive(true)
                .build();
            deviceTokenRepository.save(token);
        }
    }

    @Transactional
    public void unregisterToken(UUID userId, String token) {
        Optional<DeviceToken> existing = deviceTokenRepository.findByUserIdAndToken(userId, token);
        existing.ifPresent(deviceToken -> {
            deviceToken.setActive(false);
            deviceTokenRepository.save(deviceToken);
        });
    }

    public List<DeviceToken> getActiveTokens(UUID userId) {
        return deviceTokenRepository.findAllByUserIdAndIsActive(userId, true);
    }
}
