package com.pockettalk.game.engine;

import com.pockettalk.auth.entity.User;
import com.pockettalk.common.model.HandState;
import com.pockettalk.game.entity.Hand;
import com.pockettalk.game.entity.HandPlayer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class GameStateMachineTest {

    private GameStateMachine stateMachine;
    private Hand hand;

    @BeforeEach
    void setUp() {
        stateMachine = new GameStateMachine();
        hand = Hand.builder()
                .id(UUID.randomUUID())
                .handNumber(1)
                .dealerSeat(1)
                .smallBlindAmt(10)
                .bigBlindAmt(20)
                .potTotal(30)
                .state(HandState.PRE_FLOP)
                .build();
    }

    private User makeUser() {
        return User.builder()
                .id(UUID.randomUUID())
                .email("test@test.com")
                .passwordHash("hash")
                .nickname("user")
                .build();
    }

    private HandPlayer makeHandPlayer(String status) {
        return HandPlayer.builder()
                .id(UUID.randomUUID())
                .hand(hand)
                .user(makeUser())
                .seatNumber(1)
                .holeCards("Ah,Kh")
                .status(status)
                .betTotal(0)
                .wonAmount(0)
                .build();
    }

    private List<HandPlayer> playersWithStatuses(String... statuses) {
        List<HandPlayer> players = new ArrayList<>();
        int seat = 1;
        for (String status : statuses) {
            HandPlayer hp = HandPlayer.builder()
                    .id(UUID.randomUUID())
                    .hand(hand)
                    .user(makeUser())
                    .seatNumber(seat++)
                    .holeCards("Ah,Kh")
                    .status(status)
                    .betTotal(20)
                    .wonAmount(0)
                    .build();
            players.add(hp);
        }
        return players;
    }

    // -------------------------------------------------------
    // Normal state transitions: WAITING -> PRE_FLOP -> FLOP -> TURN -> RIVER -> SHOWDOWN
    // -------------------------------------------------------
    @Nested
    class NormalTransitionTests {

        @Test
        void preFlop_to_flop() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "ACTIVE", "ACTIVE");
            HandState next = stateMachine.transition(hand, HandState.PRE_FLOP, players);
            assertEquals(HandState.FLOP, next);
        }

        @Test
        void flop_to_turn() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "ACTIVE", "ACTIVE");
            HandState next = stateMachine.transition(hand, HandState.FLOP, players);
            assertEquals(HandState.TURN, next);
        }

        @Test
        void turn_to_river() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "ACTIVE", "ACTIVE");
            HandState next = stateMachine.transition(hand, HandState.TURN, players);
            assertEquals(HandState.RIVER, next);
        }

        @Test
        void river_to_showdown() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "ACTIVE", "ACTIVE");
            HandState next = stateMachine.transition(hand, HandState.RIVER, players);
            assertEquals(HandState.SHOWDOWN, next);
        }

        @Test
        void showdown_to_settlement() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "ACTIVE", "ACTIVE");
            HandState next = stateMachine.transition(hand, HandState.SHOWDOWN, players);
            assertEquals(HandState.SETTLEMENT, next);
        }

        @Test
        void fullNormalCycle() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "ACTIVE", "ACTIVE");

            HandState state = HandState.PRE_FLOP;
            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.FLOP, state);

            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.TURN, state);

            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.RIVER, state);

            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.SHOWDOWN, state);

            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.SETTLEMENT, state);
        }
    }

    // -------------------------------------------------------
    // Auto-advance when all fold
    // -------------------------------------------------------
    @Nested
    class AllFoldTests {

        @Test
        void preFlop_allFoldButOne_goesToSettlement() {
            // 1 active, 2 folded => nonFolded = 1 => SETTLEMENT
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "FOLDED", "FOLDED");
            HandState next = stateMachine.transition(hand, HandState.PRE_FLOP, players);
            assertEquals(HandState.SETTLEMENT, next);
        }

        @Test
        void flop_allFoldButOne_goesToSettlement() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "FOLDED", "FOLDED");
            HandState next = stateMachine.transition(hand, HandState.FLOP, players);
            assertEquals(HandState.SETTLEMENT, next);
        }

        @Test
        void turn_allFoldButOne_goesToSettlement() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "FOLDED", "FOLDED");
            HandState next = stateMachine.transition(hand, HandState.TURN, players);
            assertEquals(HandState.SETTLEMENT, next);
        }

        @Test
        void river_allFoldButOne_goesToSettlement() {
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "FOLDED", "FOLDED");
            HandState next = stateMachine.transition(hand, HandState.RIVER, players);
            assertEquals(HandState.SETTLEMENT, next);
        }

        @Test
        void noPlayersLeft_goesToSettlement() {
            // All folded (unlikely but edge case)
            List<HandPlayer> players = playersWithStatuses("FOLDED", "FOLDED", "FOLDED");
            HandState next = stateMachine.transition(hand, HandState.FLOP, players);
            assertEquals(HandState.SETTLEMENT, next);
        }

        @Test
        void oneFolded_oneOut_oneActive_normalTransition() {
            // nonFolded = 1 (ACTIVE) + 0 (FOLDED filtered) + 0 (OUT filtered) = 1 active left
            // BUT OUT is also excluded from nonFolded
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "FOLDED", "OUT");
            HandState next = stateMachine.transition(hand, HandState.PRE_FLOP, players);
            // nonFolded = count where status != FOLDED && != OUT = 1 => SETTLEMENT
            assertEquals(HandState.SETTLEMENT, next);
        }
    }

    // -------------------------------------------------------
    // Auto-advance when all-in (skip betting rounds)
    // -------------------------------------------------------
    @Nested
    class AllInTests {

        @Test
        void preFlop_allPlayersAllIn_advancesToFlop() {
            // All ALL_IN => nonFolded > 1, activePlayers = 0 => advance toward showdown
            List<HandPlayer> players = playersWithStatuses("ALL_IN", "ALL_IN", "ALL_IN");
            HandState next = stateMachine.transition(hand, HandState.PRE_FLOP, players);
            // Should advance step-by-step: PRE_FLOP -> FLOP
            assertEquals(HandState.FLOP, next);
        }

        @Test
        void flop_allPlayersAllIn_advancesToTurn() {
            List<HandPlayer> players = playersWithStatuses("ALL_IN", "ALL_IN", "ALL_IN");
            HandState next = stateMachine.transition(hand, HandState.FLOP, players);
            assertEquals(HandState.TURN, next);
        }

        @Test
        void turn_allPlayersAllIn_advancesToRiver() {
            List<HandPlayer> players = playersWithStatuses("ALL_IN", "ALL_IN", "ALL_IN");
            HandState next = stateMachine.transition(hand, HandState.TURN, players);
            assertEquals(HandState.RIVER, next);
        }

        @Test
        void river_allPlayersAllIn_advancesToShowdown() {
            List<HandPlayer> players = playersWithStatuses("ALL_IN", "ALL_IN", "ALL_IN");
            HandState next = stateMachine.transition(hand, HandState.RIVER, players);
            assertEquals(HandState.SHOWDOWN, next);
        }

        @Test
        void showdown_allPlayersAllIn_advancesToSettlement() {
            List<HandPlayer> players = playersWithStatuses("ALL_IN", "ALL_IN", "ALL_IN");
            HandState next = stateMachine.transition(hand, HandState.SHOWDOWN, players);
            assertEquals(HandState.SETTLEMENT, next);
        }

        @Test
        void preFlop_allAllIn_fullCycleToShowdown() {
            List<HandPlayer> players = playersWithStatuses("ALL_IN", "ALL_IN", "ALL_IN");

            HandState state = HandState.PRE_FLOP;
            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.FLOP, state);

            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.TURN, state);

            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.RIVER, state);

            state = stateMachine.transition(hand, state, players);
            assertEquals(HandState.SHOWDOWN, state);
        }

        @Test
        void oneActive_othersAllIn_advancesTowardShowdown() {
            // 1 ACTIVE player with 2 ALL_IN => activePlayers = 1 <= 1 => advance
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "ALL_IN", "ALL_IN");
            HandState next = stateMachine.transition(hand, HandState.PRE_FLOP, players);
            // nonFolded = 3 > 1, activePlayers = 1 <= 1 => advanceToShowdownOrNext
            assertEquals(HandState.FLOP, next);
        }

        @Test
        void oneActive_oneFolded_oneAllIn_advancesTowardShowdown() {
            // nonFolded: ACTIVE + ALL_IN = 2 > 1
            // activePlayers: only the ACTIVE = 1 <= 1 => advance
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "FOLDED", "ALL_IN");
            HandState next = stateMachine.transition(hand, HandState.FLOP, players);
            assertEquals(HandState.TURN, next);
        }

        @Test
        void twoActive_oneAllIn_normalTransition() {
            // activePlayers = 2 > 1 => normal transition
            List<HandPlayer> players = playersWithStatuses("ACTIVE", "ACTIVE", "ALL_IN");
            HandState next = stateMachine.transition(hand, HandState.PRE_FLOP, players);
            assertEquals(HandState.FLOP, next);
        }
    }

    // -------------------------------------------------------
    // HandState.next() method tests
    // -------------------------------------------------------
    @Nested
    class HandStateNextTests {

        @Test
        void waiting_next_isPreFlop() {
            assertEquals(HandState.PRE_FLOP, HandState.WAITING.next());
        }

        @Test
        void preFlop_next_isFlop() {
            assertEquals(HandState.FLOP, HandState.PRE_FLOP.next());
        }

        @Test
        void flop_next_isTurn() {
            assertEquals(HandState.TURN, HandState.FLOP.next());
        }

        @Test
        void turn_next_isRiver() {
            assertEquals(HandState.RIVER, HandState.TURN.next());
        }

        @Test
        void river_next_isShowdown() {
            assertEquals(HandState.SHOWDOWN, HandState.RIVER.next());
        }

        @Test
        void showdown_next_isSettlement() {
            assertEquals(HandState.SETTLEMENT, HandState.SHOWDOWN.next());
        }

        @Test
        void settlement_next_isWaiting() {
            assertEquals(HandState.WAITING, HandState.SETTLEMENT.next());
        }
    }
}
