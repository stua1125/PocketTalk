package com.pockettalk.auth.service;

import com.pockettalk.auth.dto.UserResponse;
import com.pockettalk.auth.entity.User;
import com.pockettalk.auth.repository.UserRepository;
import com.pockettalk.common.exception.BusinessException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;

    public UserResponse getProfile(UUID userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new BusinessException("User not found", HttpStatus.NOT_FOUND, "USER_NOT_FOUND"));
        return UserResponse.from(user);
    }

    public User getUserEntity(UUID userId) {
        return userRepository.findById(userId)
            .orElseThrow(() -> new BusinessException("User not found", HttpStatus.NOT_FOUND, "USER_NOT_FOUND"));
    }
}
