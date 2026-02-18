package com.pockettalk.game.repository;

import com.pockettalk.game.entity.HandAction;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.UUID;

public interface HandActionRepository extends JpaRepository<HandAction, UUID> {

    List<HandAction> findAllByHandIdOrderBySequenceNumAsc(UUID handId);

    /**
     * Find all actions for a hand ordered by sequence, eagerly fetching the
     * associated User to prevent N+1 queries when building action responses.
     */
    @EntityGraph(attributePaths = {"user"})
    @Query("SELECT ha FROM HandAction ha WHERE ha.hand.id = :handId ORDER BY ha.sequenceNum ASC")
    List<HandAction> findAllByHandIdWithUserOrderBySequenceNumAsc(@Param("handId") UUID handId);

    int countByHandId(UUID handId);
}
