package com.pockettalk.game.repository;

import com.pockettalk.game.entity.HandPlayer;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface HandPlayerRepository extends JpaRepository<HandPlayer, UUID> {

    List<HandPlayer> findAllByHandId(UUID handId);

    /**
     * Find all hand players for a hand, eagerly fetching the associated User
     * to prevent N+1 queries when accessing player nicknames and user IDs.
     */
    @EntityGraph(attributePaths = {"user"})
    @Query("SELECT hp FROM HandPlayer hp WHERE hp.hand.id = :handId")
    List<HandPlayer> findAllByHandIdWithUser(@Param("handId") UUID handId);

    Optional<HandPlayer> findByHandIdAndUserId(UUID handId, UUID userId);

    List<HandPlayer> findAllByHandIdAndStatusIn(UUID handId, Collection<String> statuses);
}
