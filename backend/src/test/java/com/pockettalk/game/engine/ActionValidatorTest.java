package com.pockettalk.game.engine;

import com.pockettalk.auth.entity.User;
import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.common.model.ActionType;
import com.pockettalk.common.model.HandState;
import com.pockettalk.game.entity.Hand;
import com.pockettalk.game.entity.HandPlayer;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class ActionValidatorTest {

    private ActionValidator validator;

    private UUID player1Id;
    private UUID player2Id;
    private User user1;
    private User user2;
    private Hand hand;

    @BeforeEach
    void setUp() {
        validator = new ActionValidator();

        player1Id = UUID.randomUUID();
        player2Id = UUID.randomUUID();

        user1 = User.builder().id(player1Id).email("p1@test.com")
                .passwordHash("hash").nickname("p1").build();
        user2 = User.builder().id(player2Id).email("p2@test.com")
                .passwordHash("hash").nickname("p2").build();

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

    private HandPlayer activePlayer(User user, int seat) {
        return HandPlayer.builder()
                .id(UUID.randomUUID())
                .hand(hand)
                .user(user)
                .seatNumber(seat)
                .holeCards("Ah,Kh")
                .status("ACTIVE")
                .betTotal(0)
                .wonAmount(0)
                .build();
    }

    private HandPlayer foldedPlayer(User user, int seat) {
        return HandPlayer.builder()
                .id(UUID.randomUUID())
                .hand(hand)
                .user(user)
                .seatNumber(seat)
                .holeCards("2h,3h")
                .status("FOLDED")
                .betTotal(0)
                .wonAmount(0)
                .build();
    }

    private HandPlayer allInPlayer(User user, int seat) {
        return HandPlayer.builder()
                .id(UUID.randomUUID())
                .hand(hand)
                .user(user)
                .seatNumber(seat)
                .holeCards("Qs,Js")
                .status("ALL_IN")
                .betTotal(100)
                .wonAmount(0)
                .build();
    }

    // -------------------------------------------------------
    // Valid fold
    // -------------------------------------------------------
    @Nested
    class FoldTests {

        @Test
        void fold_isAlwaysValid() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.FOLD, 0, 20, 20));
        }

        @Test
        void fold_validEvenWithNoBet() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.FOLD, 0, 0, 20));
        }
    }

    // -------------------------------------------------------
    // Valid check (when no bet)
    // -------------------------------------------------------
    @Nested
    class CheckTests {

        @Test
        void check_validWhenNoBet() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // currentBet = 0, so check is valid (basic validation in ActionValidator
            // does not throw for CHECK)
            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CHECK, 0, 0, 20));
        }
    }

    // -------------------------------------------------------
    // Invalid check (when there's a bet)
    // -------------------------------------------------------
    @Nested
    class InvalidCheckTests {

        @Test
        void check_whenBetExists_noExceptionFromBasicValidator() {
            // ActionValidator's CHECK case is a stub -- detailed check is in BettingRound.
            // The basic validator does not throw for CHECK; it defers to BettingRound.
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // This is allowed to pass at the ActionValidator level;
            // the BettingRound.isValidAction does the actual check validation
            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CHECK, 0, 50, 20));
        }
    }

    // -------------------------------------------------------
    // Valid call
    // -------------------------------------------------------
    @Nested
    class CallTests {

        @Test
        void call_validWhenBetExists() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CALL, 0, 20, 20));
        }

        @Test
        void call_invalidWhenNoBet() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CALL, 0, 0, 20));

            assertEquals("NOTHING_TO_CALL", ex.getErrorCode());
        }
    }

    // -------------------------------------------------------
    // Valid raise (minimum raise amount)
    // -------------------------------------------------------
    @Nested
    class ValidRaiseTests {

        @Test
        void raise_validWhenAboveMinimum() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // currentBet = 20, raise to 40 => increment = 20 >= minRaise 20
            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.RAISE, 40, 20, 20));
        }

        @Test
        void raise_validWhenExactlyMinRaise() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // currentBet = 20, minRaise = 20, raise to 40 => increment = 20 exactly
            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.RAISE, 40, 20, 20));
        }

        @Test
        void raise_validLargeAmount() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // currentBet = 20, raise to 500 => increment = 480 >> minRaise 20
            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.RAISE, 500, 20, 20));
        }
    }

    // -------------------------------------------------------
    // Invalid raise (below minimum)
    // -------------------------------------------------------
    @Nested
    class InvalidRaiseTests {

        @Test
        void raise_zeroAmount_throws() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.RAISE, 0, 20, 20));

            assertEquals("INVALID_RAISE_AMOUNT", ex.getErrorCode());
        }

        @Test
        void raise_belowCurrentBet_throws() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // currentBet = 40, raise to 30 => less than current bet
            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.RAISE, 30, 40, 20));

            assertEquals("RAISE_TOO_LOW", ex.getErrorCode());
        }

        @Test
        void raise_incrementBelowMinRaise_throws() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // currentBet = 20, raise to 25 => increment = 5 < minRaise 20
            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.RAISE, 25, 20, 20));

            assertEquals("RAISE_TOO_SMALL", ex.getErrorCode());
        }
    }

    // -------------------------------------------------------
    // All-in validation
    // -------------------------------------------------------
    @Nested
    class AllInTests {

        @Test
        void allIn_validForActivePlayer() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.ALL_IN, 0, 20, 20));
        }

        @Test
        void allIn_invalidForAlreadyAllInPlayer() {
            HandPlayer hp1 = allInPlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.ALL_IN, 0, 20, 20));

            assertEquals("PLAYER_ALL_IN", ex.getErrorCode());
        }
    }

    // -------------------------------------------------------
    // Out of turn action rejection
    // -------------------------------------------------------
    @Nested
    class OutOfTurnTests {

        @Test
        void action_outOfTurn_throws() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // It's player1's turn, but player2 tries to act
            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp2, allPlayers, player1Id, player2Id,
                            ActionType.CHECK, 0, 0, 20));

            assertEquals("NOT_YOUR_TURN", ex.getErrorCode());
        }

        @Test
        void action_outOfTurn_fold_throws() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // Even folding out of turn is rejected
            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp2, allPlayers, player1Id, player2Id,
                            ActionType.FOLD, 0, 0, 20));

            assertEquals("NOT_YOUR_TURN", ex.getErrorCode());
        }
    }

    // -------------------------------------------------------
    // Invalid hand state
    // -------------------------------------------------------
    @Nested
    class InvalidHandStateTests {

        @Test
        void action_inWaitingState_throws() {
            hand.setState(HandState.WAITING);
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CHECK, 0, 0, 20));

            assertEquals("INVALID_HAND_STATE", ex.getErrorCode());
        }

        @Test
        void action_inShowdownState_throws() {
            hand.setState(HandState.SHOWDOWN);
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CHECK, 0, 0, 20));

            assertEquals("INVALID_HAND_STATE", ex.getErrorCode());
        }

        @Test
        void action_inSettlementState_throws() {
            hand.setState(HandState.SETTLEMENT);
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.FOLD, 0, 0, 20));

            assertEquals("INVALID_HAND_STATE", ex.getErrorCode());
        }

        @Test
        void action_inFlopState_isValid() {
            hand.setState(HandState.FLOP);
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CHECK, 0, 0, 20));
        }

        @Test
        void action_inTurnState_isValid() {
            hand.setState(HandState.TURN);
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.FOLD, 0, 0, 20));
        }

        @Test
        void action_inRiverState_isValid() {
            hand.setState(HandState.RIVER);
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            assertDoesNotThrow(() ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CALL, 0, 20, 20));
        }
    }

    // -------------------------------------------------------
    // Player not in hand / invalid status
    // -------------------------------------------------------
    @Nested
    class PlayerStatusTests {

        @Test
        void nullHandPlayer_throws() {
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, null, allPlayers, player1Id, player1Id,
                            ActionType.CHECK, 0, 0, 20));

            assertEquals("NOT_IN_HAND", ex.getErrorCode());
        }

        @Test
        void foldedPlayer_cannotAct() {
            HandPlayer hp1 = foldedPlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.CHECK, 0, 0, 20));

            assertEquals("PLAYER_CANNOT_ACT", ex.getErrorCode());
        }

        @Test
        void invalidActionType_throws() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            // DEAL_FLOP is not a player action
            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.DEAL_FLOP, 0, 0, 20));

            assertEquals("INVALID_ACTION_TYPE", ex.getErrorCode());
        }

        @Test
        void settleAction_isInvalidType() {
            HandPlayer hp1 = activePlayer(user1, 1);
            HandPlayer hp2 = activePlayer(user2, 2);
            List<HandPlayer> allPlayers = List.of(hp1, hp2);

            BusinessException ex = assertThrows(BusinessException.class, () ->
                    validator.validateAction(hand, hp1, allPlayers, player1Id, player1Id,
                            ActionType.SETTLE, 0, 0, 20));

            assertEquals("INVALID_ACTION_TYPE", ex.getErrorCode());
        }
    }
}
