package com.pockettalk.notification.repository;

import com.pockettalk.notification.entity.DeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {

    List<DeviceToken> findAllByUserIdAndIsActive(UUID userId, boolean isActive);

    Optional<DeviceToken> findByUserIdAndToken(UUID userId, String token);

    void deleteByUserIdAndToken(UUID userId, String token);
}
