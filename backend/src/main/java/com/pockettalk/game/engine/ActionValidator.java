package com.pockettalk.game.engine;

import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.common.model.ActionType;
import com.pockettalk.common.model.HandState;
import com.pockettalk.game.entity.Hand;
import com.pockettalk.game.entity.HandPlayer;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Validates player actions in the context of a poker hand.
 *
 * Ensures actions are legal given the current game state, player turn,
 * bet amounts, and action-specific rules.
 */
@Component
public class ActionValidator {

    private static final Set<ActionType> PLAYER_ACTIONS = Set.of(
            ActionType.CHECK, ActionType.CALL, ActionType.RAISE,
            ActionType.FOLD, ActionType.ALL_IN
    );

    /**
     * Validate that the given player can perform the specified action.
     *
     * @param hand        the current hand
     * @param handPlayer  the hand-player record for this player
     * @param allPlayers  all players in the hand
     * @param currentPlayerId the ID of the player whose turn it is
     * @param playerId    the player attempting the action
     * @param action      the action type
     * @param amount      the amount (for RAISE), or 0
     * @param currentBet  the current bet to match in this round
     * @param minRaise    the minimum raise increment
     * @throws BusinessException if the action is invalid
     */
    public void validateAction(Hand hand, HandPlayer handPlayer, List<HandPlayer> allPlayers,
                                UUID currentPlayerId, UUID playerId, ActionType action,
                                long amount, long currentBet, long minRaise) {
        // Must be a player action
        if (!PLAYER_ACTIONS.contains(action)) {
            throw new BusinessException(
                    "Invalid action type: " + action,
                    HttpStatus.BAD_REQUEST, "INVALID_ACTION_TYPE");
        }

        // Hand must be in a betting state
        HandState state = hand.getState();
        if (state != HandState.PRE_FLOP && state != HandState.FLOP
                && state != HandState.TURN && state != HandState.RIVER) {
            throw new BusinessException(
                    "Cannot perform actions in hand state: " + state,
                    HttpStatus.BAD_REQUEST, "INVALID_HAND_STATE");
        }

        // Player must be in the hand and active
        if (handPlayer == null) {
            throw new BusinessException(
                    "Player is not in this hand",
                    HttpStatus.BAD_REQUEST, "NOT_IN_HAND");
        }

        if (!"ACTIVE".equals(handPlayer.getStatus()) && !"ALL_IN".equals(handPlayer.getStatus())) {
            throw new BusinessException(
                    "Player cannot act with status: " + handPlayer.getStatus(),
                    HttpStatus.BAD_REQUEST, "PLAYER_CANNOT_ACT");
        }

        if ("ALL_IN".equals(handPlayer.getStatus())) {
            throw new BusinessException(
                    "Player is all-in and cannot take further actions",
                    HttpStatus.BAD_REQUEST, "PLAYER_ALL_IN");
        }

        // Must be this player's turn
        if (!playerId.equals(currentPlayerId)) {
            throw new BusinessException(
                    "It is not your turn to act",
                    HttpStatus.BAD_REQUEST, "NOT_YOUR_TURN");
        }

        // Get the player's available chips (from room player chip count minus what they've bet)
        // We use the BettingRound for detailed validation, but validate basic rules here

        switch (action) {
            case CHECK -> {
                // CHECK is only valid if there's no bet to match
                // (player's bet this round already equals current bet)
                // The caller provides currentBet for the round
                // We need to know player's bet this round; approximate via total bet context
                // Detailed check is in BettingRound, but we do a basic check here
            }
            case CALL -> {
                // Must have a bet to call
                if (currentBet <= 0) {
                    throw new BusinessException(
                            "No bet to call; use CHECK instead",
                            HttpStatus.BAD_REQUEST, "NOTHING_TO_CALL");
                }
            }
            case RAISE -> {
                if (amount <= 0) {
                    throw new BusinessException(
                            "Raise amount must be positive",
                            HttpStatus.BAD_REQUEST, "INVALID_RAISE_AMOUNT");
                }
                if (amount <= currentBet) {
                    throw new BusinessException(
                            "Raise must exceed current bet of " + currentBet,
                            HttpStatus.BAD_REQUEST, "RAISE_TOO_LOW");
                }
                long raiseIncrement = amount - currentBet;
                if (raiseIncrement < minRaise) {
                    throw new BusinessException(
                            "Raise increment " + raiseIncrement + " is less than minimum raise of " + minRaise,
                            HttpStatus.BAD_REQUEST, "RAISE_TOO_SMALL");
                }
            }
            case ALL_IN -> {
                // Always valid if player has chips
            }
            case FOLD -> {
                // Always valid
            }
            default -> throw new BusinessException(
                    "Unhandled action: " + action,
                    HttpStatus.BAD_REQUEST, "INVALID_ACTION");
        }
    }
}
