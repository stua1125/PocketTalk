package com.pockettalk.game.entity;

import com.pockettalk.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.util.UUID;

@Entity
@Table(name = "hand_players", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"hand_id", "user_id"})
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HandPlayer {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hand_id", nullable = false)
    private Hand hand;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "seat_number", nullable = false)
    private int seatNumber;

    @Column(name = "hole_cards", length = 10)
    private String holeCards;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "ACTIVE";

    @Column(name = "bet_total", nullable = false)
    @Builder.Default
    private long betTotal = 0;

    @Column(name = "won_amount", nullable = false)
    @Builder.Default
    private long wonAmount = 0;

    @Column(name = "best_hand_rank", length = 30)
    private String bestHandRank;

    @Column(name = "best_hand_cards", length = 30)
    private String bestHandCards;
}
