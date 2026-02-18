package com.pockettalk.game.entity;

import com.pockettalk.auth.entity.User;
import com.pockettalk.common.model.ActionType;
import com.pockettalk.common.model.HandState;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "hand_actions")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HandAction {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "hand_id", nullable = false)
    private Hand hand;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "action_type", nullable = false, length = 20)
    private ActionType actionType;

    @Column(nullable = false)
    @Builder.Default
    private long amount = 0;

    @Enumerated(EnumType.STRING)
    @Column(name = "hand_state", nullable = false, length = 20)
    private HandState handState;

    @Column(name = "sequence_num", nullable = false)
    private int sequenceNum;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
