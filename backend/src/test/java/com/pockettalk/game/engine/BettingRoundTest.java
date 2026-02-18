package com.pockettalk.game.engine;

import com.pockettalk.common.model.ActionType;
import com.pockettalk.game.engine.BettingRound.PlayerState;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class BettingRoundTest {

    private BettingRound round;

    private final UUID player1 = UUID.randomUUID();
    private final UUID player2 = UUID.randomUUID();
    private final UUID player3 = UUID.randomUUID();

    /**
     * Helper to create player states for a basic 3-player game.
     * Each player starts with 1000 chips.
     */
    private List<PlayerState> threePlayersWithChips(long chips) {
        return List.of(
                new PlayerState(player1, 1, chips),
                new PlayerState(player2, 2, chips),
                new PlayerState(player3, 3, chips)
        );
    }

    // -------------------------------------------------------
    // Basic betting round flow
    // -------------------------------------------------------
    @Nested
    class BasicFlowTests {

        @Test
        void init_setsCurrentBetAndMinRaise() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertEquals(0, round.getCurrentBet());
            assertEquals(20, round.getMinRaise());
        }

        @Test
        void init_allPlayersTrackable() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertNotNull(round.getPlayerState(player1));
            assertNotNull(round.getPlayerState(player2));
            assertNotNull(round.getPlayerState(player3));
        }

        @Test
        void getNextPlayer_returnsFirstUnactedPlayer() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // After init with startIndex=0, lastActorIndex is set to
            // (0-1+3)%3 = 2, so next player starts from index (2+1)%3 = 0
            UUID nextPlayer = round.getNextPlayer();
            assertNotNull(nextPlayer);
        }

        @Test
        void processAction_check_marksPlayerAsActed() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            UUID next = round.getNextPlayer();
            round.processAction(next, ActionType.CHECK, 0);

            PlayerState ps = round.getPlayerState(next);
            assertTrue(ps.hasActed());
            assertFalse(ps.hasFolded());
            assertFalse(ps.isAllIn());
        }
    }

    // -------------------------------------------------------
    // Check around
    // -------------------------------------------------------
    @Nested
    class CheckAroundTests {

        @Test
        void allPlayersCheck_roundCompletes() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertFalse(round.isRoundComplete());

            // All three players check
            round.processAction(player1, ActionType.CHECK, 0);
            assertFalse(round.isRoundComplete());

            round.processAction(player2, ActionType.CHECK, 0);
            assertFalse(round.isRoundComplete());

            round.processAction(player3, ActionType.CHECK, 0);
            assertTrue(round.isRoundComplete());
        }

        @Test
        void allPlayersCheck_noChipChanges() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            round.processAction(player1, ActionType.CHECK, 0);
            round.processAction(player2, ActionType.CHECK, 0);
            round.processAction(player3, ActionType.CHECK, 0);

            assertEquals(1000, round.getPlayerState(player1).getChipCount());
            assertEquals(1000, round.getPlayerState(player2).getChipCount());
            assertEquals(1000, round.getPlayerState(player3).getChipCount());
        }

        @Test
        void afterAllCheck_getNextPlayerReturnsNull() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            round.processAction(player1, ActionType.CHECK, 0);
            round.processAction(player2, ActionType.CHECK, 0);
            round.processAction(player3, ActionType.CHECK, 0);

            assertNull(round.getNextPlayer());
        }
    }

    // -------------------------------------------------------
    // Bet and call sequence
    // -------------------------------------------------------
    @Nested
    class BetAndCallTests {

        @Test
        void raise_thenCallByOthers_completesRound() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Player1 raises to 40
            round.processAction(player1, ActionType.RAISE, 40);
            assertEquals(40, round.getCurrentBet());
            assertFalse(round.isRoundComplete());

            // Player2 calls 40
            round.processAction(player2, ActionType.CALL, 0);
            assertFalse(round.isRoundComplete());

            // Player3 calls 40
            round.processAction(player3, ActionType.CALL, 0);
            assertTrue(round.isRoundComplete());
        }

        @Test
        void raise_thenCall_chipsDeductedCorrectly() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Player1 raises to 40
            round.processAction(player1, ActionType.RAISE, 40);
            assertEquals(960, round.getPlayerState(player1).getChipCount());
            assertEquals(40, round.getPlayerState(player1).getBetThisRound());

            // Player2 calls
            round.processAction(player2, ActionType.CALL, 0);
            assertEquals(960, round.getPlayerState(player2).getChipCount());
            assertEquals(40, round.getPlayerState(player2).getBetThisRound());
        }

        @Test
        void fold_thenCall_roundCompletes() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Player1 raises to 50
            round.processAction(player1, ActionType.RAISE, 50);

            // Player2 folds
            round.processAction(player2, ActionType.FOLD, 0);
            assertTrue(round.getPlayerState(player2).hasFolded());

            // Player3 calls
            round.processAction(player3, ActionType.CALL, 0);
            assertTrue(round.isRoundComplete());
        }
    }

    // -------------------------------------------------------
    // Raise and re-raise
    // -------------------------------------------------------
    @Nested
    class RaiseAndReRaiseTests {

        @Test
        void raise_thenReRaise_updatesCurrentBet() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Player1 raises to 40
            round.processAction(player1, ActionType.RAISE, 40);
            assertEquals(40, round.getCurrentBet());

            // Player2 re-raises to 100
            round.processAction(player2, ActionType.RAISE, 100);
            assertEquals(100, round.getCurrentBet());
        }

        @Test
        void raise_thenReRaise_resetsActedFlags() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Player1 raises to 40
            round.processAction(player1, ActionType.RAISE, 40);

            // Player2 re-raises to 100
            round.processAction(player2, ActionType.RAISE, 100);

            // Player1 must act again -- their hasActed flag was reset
            assertFalse(round.isRoundComplete());
            // Player3 also needs to act
            assertFalse(round.getPlayerState(player3).hasActed());
        }

        @Test
        void raise_reRaise_allCall_completesRound() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Player1 raises to 40
            round.processAction(player1, ActionType.RAISE, 40);

            // Player2 re-raises to 100
            round.processAction(player2, ActionType.RAISE, 100);

            // Player3 calls
            round.processAction(player3, ActionType.CALL, 0);
            assertFalse(round.isRoundComplete()); // Player1 still needs to act

            // Player1 calls
            round.processAction(player1, ActionType.CALL, 0);
            assertTrue(round.isRoundComplete());
        }

        @Test
        void minRaise_updatesAfterLargerRaise() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Raise to 40 (increment of 40, which is > initial minRaise of 20)
            round.processAction(player1, ActionType.RAISE, 40);
            assertEquals(40, round.getMinRaise());

            // Re-raise to 120 (increment of 80, larger than previous minRaise of 40)
            round.processAction(player2, ActionType.RAISE, 120);
            assertEquals(80, round.getMinRaise());
        }
    }

    // -------------------------------------------------------
    // All-in scenario
    // -------------------------------------------------------
    @Nested
    class AllInTests {

        @Test
        void allIn_setsPlayerAllInFlag() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            round.processAction(player1, ActionType.ALL_IN, 0);

            PlayerState ps = round.getPlayerState(player1);
            assertTrue(ps.isAllIn());
            assertEquals(0, ps.getChipCount());
            assertEquals(1000, ps.getBetThisRound());
        }

        @Test
        void allIn_forLessThanCurrentBet_doesNotResetOthersActions() {
            round = new BettingRound();
            // Player1 has only 30 chips, others have 1000
            List<PlayerState> states = List.of(
                    new PlayerState(player1, 1, 30),
                    new PlayerState(player2, 2, 1000),
                    new PlayerState(player3, 3, 1000)
            );
            round.init(states, 0, 20, 0);

            // Player2 raises to 50
            round.processAction(player2, ActionType.RAISE, 50);

            // Player3 calls
            round.processAction(player3, ActionType.CALL, 0);

            // Player1 goes all-in for 30 (less than current bet of 50)
            round.processAction(player1, ActionType.ALL_IN, 0);

            // Since all-in for 30 is less than minRaise above current bet,
            // it should NOT reset others' acted flags.
            // Round should be complete since player2 and player3 have acted
            // and player1 is all-in.
            assertTrue(round.isRoundComplete());
        }

        @Test
        void allIn_exceedingCurrentBet_resetsActedFlags() {
            round = new BettingRound();
            List<PlayerState> states = List.of(
                    new PlayerState(player1, 1, 1000),
                    new PlayerState(player2, 2, 500),
                    new PlayerState(player3, 3, 1000)
            );
            round.init(states, 0, 20, 0);

            // Player1 raises to 40
            round.processAction(player1, ActionType.RAISE, 40);

            // Player2 goes all-in for 500 (exceeds current bet by 460, well above minRaise)
            round.processAction(player2, ActionType.ALL_IN, 0);
            assertEquals(500, round.getCurrentBet());

            // Player1 and Player3's hasActed flags should be reset
            assertFalse(round.isRoundComplete());
        }

        @Test
        void allPlayers_allIn_roundCompletes() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            round.processAction(player1, ActionType.ALL_IN, 0);
            round.processAction(player2, ActionType.ALL_IN, 0);
            round.processAction(player3, ActionType.ALL_IN, 0);

            assertTrue(round.isRoundComplete());
        }
    }

    // -------------------------------------------------------
    // Round completion detection
    // -------------------------------------------------------
    @Nested
    class RoundCompletionTests {

        @Test
        void roundNotComplete_whenPlayersHaveNotActed() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertFalse(round.isRoundComplete());
        }

        @Test
        void roundComplete_whenOnlyOneActivePlayer() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Player1 raises
            round.processAction(player1, ActionType.RAISE, 40);

            // Player2 folds
            round.processAction(player2, ActionType.FOLD, 0);

            // Player3 folds
            round.processAction(player3, ActionType.FOLD, 0);

            // Only one active player -- round complete
            assertTrue(round.isRoundComplete());
        }

        @Test
        void roundComplete_afterBetsAreMatched() {
            round = new BettingRound();
            List<PlayerState> states = List.of(
                    new PlayerState(player1, 1, 1000),
                    new PlayerState(player2, 2, 1000)
            );
            round.init(states, 0, 20, 0);

            round.processAction(player1, ActionType.RAISE, 50);
            assertFalse(round.isRoundComplete());

            round.processAction(player2, ActionType.CALL, 0);
            assertTrue(round.isRoundComplete());
        }

        @Test
        void getNonFoldedPlayers_excludesFolded() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertEquals(3, round.getNonFoldedPlayers().size());

            round.processAction(player1, ActionType.FOLD, 0);

            assertEquals(2, round.getNonFoldedPlayers().size());
            assertEquals(2, round.countNonFolded());
        }

        @Test
        void getActivePlayers_excludesFoldedAndAllIn() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertEquals(3, round.getActivePlayers().size());

            round.processAction(player1, ActionType.FOLD, 0);
            round.processAction(player2, ActionType.ALL_IN, 0);

            // Only player3 is active (not folded, not all-in)
            assertEquals(1, round.getActivePlayers().size());
            assertEquals(player3, round.getActivePlayers().get(0).getPlayerId());
        }
    }

    // -------------------------------------------------------
    // Validation within BettingRound
    // -------------------------------------------------------
    @Nested
    class ValidationTests {

        @Test
        void isValidAction_check_validWhenNoBet() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertTrue(round.isValidAction(player1, ActionType.CHECK, 0));
        }

        @Test
        void isValidAction_check_invalidWhenBetExists() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 50, 20, 0);

            // Current bet is 50, players have 0 bet this round, so they can't check
            assertFalse(round.isValidAction(player1, ActionType.CHECK, 0));
        }

        @Test
        void isValidAction_fold_alwaysValid() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertTrue(round.isValidAction(player1, ActionType.FOLD, 0));
        }

        @Test
        void isValidAction_call_validWhenBetExists() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 50, 20, 0);

            assertTrue(round.isValidAction(player1, ActionType.CALL, 0));
        }

        @Test
        void isValidAction_call_invalidWhenNoBet() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // No bet to call (toCall = 0 - 0 = 0, which fails toCall > 0)
            assertFalse(round.isValidAction(player1, ActionType.CALL, 0));
        }

        @Test
        void isValidAction_raise_validAboveMinimum() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Raise to 20: raiseAmount = 20 - 0 = 20, which equals minRaise of 20
            assertTrue(round.isValidAction(player1, ActionType.RAISE, 20));
        }

        @Test
        void isValidAction_raise_invalidBelowMinimum() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            // Raise to 10: raiseAmount = 10 - 0 = 10, which is < minRaise of 20
            assertFalse(round.isValidAction(player1, ActionType.RAISE, 10));
        }

        @Test
        void isValidAction_foldedPlayer_cannotAct() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            round.processAction(player1, ActionType.FOLD, 0);

            assertFalse(round.isValidAction(player1, ActionType.CHECK, 0));
            assertFalse(round.isValidAction(player1, ActionType.RAISE, 40));
        }

        @Test
        void isValidAction_allInPlayer_cannotAct() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            round.processAction(player1, ActionType.ALL_IN, 0);

            assertFalse(round.isValidAction(player1, ActionType.CHECK, 0));
            assertFalse(round.isValidAction(player1, ActionType.RAISE, 40));
        }

        @Test
        void isValidAction_allIn_validWhenPlayerHasChips() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            assertTrue(round.isValidAction(player1, ActionType.ALL_IN, 0));
        }

        @Test
        void isValidAction_unknownPlayer_returnsFalse() {
            round = new BettingRound();
            round.init(threePlayersWithChips(1000), 0, 20, 0);

            UUID unknown = UUID.randomUUID();
            assertFalse(round.isValidAction(unknown, ActionType.CHECK, 0));
        }
    }

    // -------------------------------------------------------
    // Pre-flop style with blinds
    // -------------------------------------------------------
    @Nested
    class PreFlopWithBlindsTests {

        @Test
        void preFlopStyle_blindsSetAsCurrentBet() {
            round = new BettingRound();
            // Simulate pre-flop: SB=10 posted, BB=20 posted, current bet = 20
            PlayerState sbState = new PlayerState(player1, 1, 990);
            sbState.setBetThisRound(10);
            sbState.setHasActed(false); // SB hasn't voluntarily acted yet

            PlayerState bbState = new PlayerState(player2, 2, 980);
            bbState.setBetThisRound(20);
            bbState.setHasActed(false); // BB hasn't voluntarily acted yet

            PlayerState utg = new PlayerState(player3, 3, 1000);

            round.init(List.of(sbState, bbState, utg), 20, 20, 0);

            // UTG should need to call 20 or raise
            assertFalse(round.isValidAction(player3, ActionType.CHECK, 0)); // can't check, 20 to call
            assertTrue(round.isValidAction(player3, ActionType.CALL, 0));
            assertTrue(round.isValidAction(player3, ActionType.RAISE, 40)); // raise to 40
        }
    }
}
