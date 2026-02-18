package com.pockettalk.auth.service;

import com.pockettalk.auth.dto.*;
import com.pockettalk.auth.entity.User;
import com.pockettalk.auth.repository.UserRepository;
import com.pockettalk.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;

    @Transactional
    public TokenResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new BusinessException("Email already exists", HttpStatus.CONFLICT, "DUPLICATE_EMAIL");
        }
        if (userRepository.existsByNickname(request.nickname())) {
            throw new BusinessException("Nickname already exists", HttpStatus.CONFLICT, "DUPLICATE_NICKNAME");
        }

        User user = User.builder()
            .email(request.email())
            .passwordHash(passwordEncoder.encode(request.password()))
            .nickname(request.nickname())
            .build();
        user = userRepository.save(user);

        return createTokenResponse(user.getId());
    }

    public TokenResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.email())
            .orElseThrow(() -> new BusinessException("Invalid email or password", HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS"));

        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BusinessException("Invalid email or password", HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS");
        }

        return createTokenResponse(user.getId());
    }

    public TokenResponse refresh(RefreshRequest request) {
        if (!jwtTokenProvider.validateToken(request.refreshToken())) {
            throw new BusinessException("Invalid refresh token", HttpStatus.UNAUTHORIZED, "INVALID_TOKEN");
        }
        if (jwtTokenProvider.isAccessToken(request.refreshToken())) {
            throw new BusinessException("Access token cannot be used as refresh token", HttpStatus.UNAUTHORIZED, "INVALID_TOKEN_TYPE");
        }
        String userId = jwtTokenProvider.getUserIdFromToken(request.refreshToken());
        return createTokenResponse(UUID.fromString(userId));
    }

    private TokenResponse createTokenResponse(UUID userId) {
        String accessToken = jwtTokenProvider.generateAccessToken(userId);
        String refreshToken = jwtTokenProvider.generateRefreshToken(userId);
        return new TokenResponse(accessToken, refreshToken, 3600);
    }
}
