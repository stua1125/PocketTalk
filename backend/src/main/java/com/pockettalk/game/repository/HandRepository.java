package com.pockettalk.game.repository;

import com.pockettalk.game.entity.Hand;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface HandRepository extends JpaRepository<Hand, UUID> {

    Optional<Hand> findTopByRoomIdOrderByHandNumberDesc(UUID roomId);

    Page<Hand> findAllByRoomIdOrderByHandNumberDesc(UUID roomId, Pageable pageable);

    /**
     * Find a hand by ID, eagerly fetching the Room association
     * to prevent a lazy-load query when accessing hand.getRoom().
     */
    @EntityGraph(attributePaths = {"room"})
    @Query("SELECT h FROM Hand h WHERE h.id = :id")
    Optional<Hand> findByIdWithRoom(@Param("id") UUID id);

    /**
     * Find a hand by ID with a pessimistic write lock (SELECT ... FOR UPDATE).
     * Use this for game state mutations to prevent concurrent modification.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT h FROM Hand h WHERE h.id = :id")
    Optional<Hand> findByIdForUpdate(@Param("id") UUID id);

    @Query("""
        SELECT CASE WHEN COUNT(hp) > 0 THEN true ELSE false END
        FROM HandPlayer hp
        JOIN hp.hand h
        WHERE h.room.id = :roomId
          AND hp.user.id = :userId
          AND hp.status = 'ACTIVE'
          AND h.state NOT IN (com.pockettalk.common.model.HandState.SETTLEMENT)
        """)
    boolean isPlayerInActiveHand(@Param("roomId") UUID roomId, @Param("userId") UUID userId);
}
