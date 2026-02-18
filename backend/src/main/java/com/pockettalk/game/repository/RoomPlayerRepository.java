package com.pockettalk.game.repository;

import com.pockettalk.game.entity.RoomPlayer;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RoomPlayerRepository extends JpaRepository<RoomPlayer, UUID> {

    Optional<RoomPlayer> findByRoomIdAndUserId(UUID roomId, UUID userId);

    Optional<RoomPlayer> findByRoomIdAndUserIdAndStatus(UUID roomId, UUID userId, String status);

    List<RoomPlayer> findAllByRoomId(UUID roomId);

    /**
     * Find all room players for a room, eagerly fetching the associated User
     * to prevent N+1 queries when building chip count lookups by user ID.
     */
    @EntityGraph(attributePaths = {"user"})
    @Query("SELECT rp FROM RoomPlayer rp WHERE rp.room.id = :roomId")
    List<RoomPlayer> findAllByRoomIdWithUser(@Param("roomId") UUID roomId);

    List<RoomPlayer> findAllByRoomIdAndStatus(UUID roomId, String status);

    List<RoomPlayer> findAllByUserId(UUID userId);

    int countByRoomId(UUID roomId);

    int countByRoomIdAndStatus(UUID roomId, String status);

    boolean existsByRoomIdAndSeatNumberAndStatus(UUID roomId, int seatNumber, String status);

    boolean existsByRoomIdAndUserIdAndStatus(UUID roomId, UUID userId, String status);
}
