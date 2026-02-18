package com.pockettalk.game.entity;

import com.pockettalk.auth.entity.User;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "rooms")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Room {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 100)
    private String name;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id", nullable = false)
    private User owner;

    @Column(name = "max_players", nullable = false)
    @Builder.Default
    private int maxPlayers = 9;

    @Column(name = "small_blind", nullable = false)
    private long smallBlind;

    @Column(name = "big_blind", nullable = false)
    private long bigBlind;

    @Column(name = "buy_in_min", nullable = false)
    private long buyInMin;

    @Column(name = "buy_in_max", nullable = false)
    private long buyInMax;

    @Column(nullable = false, length = 20)
    @Builder.Default
    private String status = "WAITING";

    @Column(name = "invite_code", unique = true, length = 20)
    private String inviteCode;

    @Column(name = "auto_start_delay", nullable = false)
    @Builder.Default
    private int autoStartDelay = 30;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}
