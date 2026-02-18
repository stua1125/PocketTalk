package com.pockettalk.game.repository;

import com.pockettalk.game.entity.Room;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface RoomRepository extends JpaRepository<Room, UUID> {

    Optional<Room> findByInviteCode(String inviteCode);

    List<Room> findByStatusIn(Collection<String> statuses);

    List<Room> findAllByOwnerId(UUID ownerId);

    boolean existsByInviteCode(String inviteCode);

    @Query("""
        SELECT DISTINCT r FROM Room r
        LEFT JOIN RoomPlayer rp ON rp.room = r AND rp.status = 'ACTIVE'
        WHERE (r.owner.id = :userId OR rp.user.id = :userId)
          AND r.status <> 'CLOSED'
        ORDER BY r.createdAt DESC
        """)
    List<Room> findRoomsByOwnerOrPlayer(@Param("userId") UUID userId);
}
