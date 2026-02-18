package com.pockettalk.game.entity;

import com.pockettalk.common.model.HandState;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "hands")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Hand {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "room_id", nullable = false)
    private Room room;

    @Column(name = "hand_number", nullable = false)
    private long handNumber;

    @Column(name = "dealer_seat", nullable = false)
    private int dealerSeat;

    @Column(name = "small_blind_amt", nullable = false)
    private long smallBlindAmt;

    @Column(name = "big_blind_amt", nullable = false)
    private long bigBlindAmt;

    @Column(name = "community_cards", length = 30)
    private String communityCards;

    @Column(name = "pot_total", nullable = false)
    @Builder.Default
    private long potTotal = 0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private HandState state = HandState.WAITING;

    @CreationTimestamp
    @Column(name = "started_at", nullable = false, updatable = false)
    private Instant startedAt;

    @Column(name = "ended_at")
    private Instant endedAt;
}
