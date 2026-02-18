package com.pockettalk.game.engine;

import com.pockettalk.common.model.HandState;
import com.pockettalk.game.entity.Hand;
import com.pockettalk.game.entity.HandPlayer;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Manages hand state transitions in a poker game.
 *
 * Determines the next state based on the current state and the status
 * of players in the hand.
 */
@Component
public class GameStateMachine {

    /**
     * Determine the next state for the hand.
     *
     * Rules:
     * - If only one non-folded player remains, go directly to SETTLEMENT.
     * - If all remaining players are ALL_IN (no active players who can bet),
     *   advance through community card states to SHOWDOWN.
     * - Otherwise, advance to the next normal state.
     *
     * @param hand           the current hand
     * @param currentState   the current hand state
     * @param handPlayers    all players in the hand
     * @return the next HandState
     */
    public HandState transition(Hand hand, HandState currentState, List<HandPlayer> handPlayers) {
        long nonFolded = handPlayers.stream()
                .filter(p -> !"FOLDED".equals(p.getStatus()) && !"OUT".equals(p.getStatus()))
                .count();

        long activePlayers = handPlayers.stream()
                .filter(p -> "ACTIVE".equals(p.getStatus()))
                .count();

        // Only one player left (everyone else folded) - go to settlement
        if (nonFolded <= 1) {
            return HandState.SETTLEMENT;
        }

        // All remaining players are all-in (or there's at most one active player
        // who doesn't need to bet) - skip to showdown if community cards are complete
        if (activePlayers <= 1) {
            // Everyone is all-in (possibly one active player who matched).
            // We need to deal remaining community cards, then go to showdown.
            // Advance state by state, dealing cards at each step.
            return advanceToShowdownOrNext(currentState);
        }

        // Normal transition
        return currentState.next();
    }

    /**
     * When all players are all-in, advance through deal stages toward SHOWDOWN.
     */
    private HandState advanceToShowdownOrNext(HandState currentState) {
        return switch (currentState) {
            case PRE_FLOP -> HandState.FLOP;
            case FLOP -> HandState.TURN;
            case TURN -> HandState.RIVER;
            case RIVER -> HandState.SHOWDOWN;
            case SHOWDOWN -> HandState.SETTLEMENT;
            default -> currentState.next();
        };
    }
}
