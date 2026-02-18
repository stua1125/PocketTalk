package com.pockettalk.game.service;

import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.common.model.ActionType;
import com.pockettalk.common.model.HandState;
import com.pockettalk.game.dto.HandActionResponse;
import com.pockettalk.game.dto.HandPlayerResponse;
import com.pockettalk.game.dto.HandResponse;
import com.pockettalk.game.engine.HandManager;
import com.pockettalk.game.entity.Hand;
import com.pockettalk.game.entity.HandAction;
import com.pockettalk.game.entity.HandPlayer;
import com.pockettalk.game.entity.RoomPlayer;
import com.pockettalk.game.repository.HandActionRepository;
import com.pockettalk.game.repository.HandPlayerRepository;
import com.pockettalk.game.repository.HandRepository;
import com.pockettalk.game.repository.RoomPlayerRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class HandService {

    private final HandManager handManager;
    private final HandRepository handRepository;
    private final HandPlayerRepository handPlayerRepository;
    private final HandActionRepository handActionRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final TurnTimerService turnTimerService;

    /**
     * Start a new hand in the room.
     * Validates the requesting user is an active player in the room,
     * then delegates to HandManager.startNewHand().
     */
    @Transactional
    public HandResponse startHand(UUID roomId, UUID requestingUserId) {
        roomPlayerRepository.findByRoomIdAndUserIdAndStatus(roomId, requestingUserId, "ACTIVE")
                .orElseThrow(() -> new BusinessException(
                        "You are not an active player in this room",
                        HttpStatus.BAD_REQUEST, "NOT_IN_ROOM"));

        Hand hand = handManager.startNewHand(roomId);
        HandResponse response = toHandResponse(hand, requestingUserId);
        scheduleTimerIfNeeded(response);
        return response;
    }

    /**
     * Process a player action.
     * Delegates to HandManager.processAction() and returns the updated hand state.
     */
    @Transactional
    public HandResponse processAction(UUID handId, UUID playerId, ActionType action, Long amount) {
        long resolvedAmount = amount != null ? amount : 0;
        Hand hand = handManager.processAction(handId, playerId, action, resolvedAmount);
        HandResponse response = toHandResponse(hand, playerId);
        scheduleTimerIfNeeded(response);
        return response;
    }

    /**
     * Get current hand state with player-specific card visibility.
     * The requesting user sees their own hole cards. Other players' hole cards
     * are hidden unless the hand is at SHOWDOWN or SETTLEMENT and the player
     * has not folded.
     *
     * Uses @EntityGraph-backed queries to eagerly fetch associations and
     * prevent N+1 query patterns.
     */
    @Transactional(readOnly = true)
    public HandResponse getHand(UUID handId, UUID requestingUserId) {
        Hand hand = handRepository.findByIdWithRoom(handId)
                .orElseThrow(() -> new BusinessException(
                        "Hand not found", HttpStatus.NOT_FOUND, "HAND_NOT_FOUND"));
        return toHandResponse(hand, requestingUserId);
    }

    /**
     * Get action history for a hand, ordered by sequence number.
     * Uses JOIN FETCH via @EntityGraph to eagerly load User associations.
     */
    @Transactional(readOnly = true)
    public List<HandActionResponse> getActions(UUID handId) {
        handRepository.findById(handId)
                .orElseThrow(() -> new BusinessException(
                        "Hand not found", HttpStatus.NOT_FOUND, "HAND_NOT_FOUND"));

        List<HandAction> actions = handActionRepository.findAllByHandIdWithUserOrderBySequenceNumAsc(handId);
        return actions.stream()
                .map(this::toHandActionResponse)
                .toList();
    }

    /**
     * Get hand history for a room (paginated), ordered by hand number descending.
     * Card visibility is applied based on each hand's state.
     */
    @Transactional(readOnly = true)
    public List<HandResponse> getHandHistory(UUID roomId, UUID requestingUserId, int page, int size) {
        return handRepository.findAllByRoomIdOrderByHandNumberDesc(roomId, PageRequest.of(page, size))
                .getContent()
                .stream()
                .map(hand -> toHandResponse(hand, requestingUserId))
                .toList();
    }

    /**
     * Convert a Hand entity and its related data to a HandResponse DTO.
     *
     * Uses optimized repository methods with @EntityGraph to eagerly fetch
     * User associations, eliminating N+1 queries:
     * - HandPlayer.user is fetched in a single query via findAllByHandIdWithUser
     * - HandAction.user is fetched in a single query via findAllByHandIdWithUserOrderBySequenceNumAsc
     * - RoomPlayer.user is fetched in a single query via findAllByRoomIdWithUser
     *
     * Card visibility rules (critical for poker security):
     * - If the hand state is SHOWDOWN or SETTLEMENT: show all non-folded players' hole cards.
     * - Otherwise: only show the requesting user's own hole cards.
     * - Folded players' cards are always hidden regardless of hand state.
     */
    private HandResponse toHandResponse(Hand hand, UUID requestingUserId) {
        // Eagerly fetch players with their User associations (1 query instead of N+1)
        List<HandPlayer> players = handPlayerRepository.findAllByHandIdWithUser(hand.getId());

        // Eagerly fetch actions with their User associations (1 query instead of N+1)
        List<HandAction> actions = handActionRepository.findAllByHandIdWithUserOrderBySequenceNumAsc(hand.getId());

        // Eagerly fetch room players with their User associations (1 query instead of N+1)
        List<RoomPlayer> roomPlayers = roomPlayerRepository.findAllByRoomIdWithUser(hand.getRoom().getId());
        Map<UUID, RoomPlayer> rpMap = roomPlayers.stream()
                .collect(Collectors.toMap(
                        rp -> rp.getUser().getId(),
                        Function.identity(),
                        (existing, duplicate) -> existing));

        // Parse community cards
        List<String> communityCards = parseCardCodes(hand.getCommunityCards());

        boolean isShowdown = hand.getState() == HandState.SHOWDOWN
                || hand.getState() == HandState.SETTLEMENT;

        // Build player responses with card visibility
        List<HandPlayerResponse> playerResponses = players.stream().map(hp -> {
            UUID playerUserId = hp.getUser().getId();
            List<String> holeCards = null;

            boolean isRequester = playerUserId.equals(requestingUserId);
            boolean isFolded = "FOLDED".equals(hp.getStatus());

            if (isRequester || (isShowdown && !isFolded)) {
                holeCards = parseCardCodes(hp.getHoleCards());
            }

            RoomPlayer rp = rpMap.get(playerUserId);
            long chipCount = rp != null ? rp.getChipCount() : 0;

            return new HandPlayerResponse(
                    playerUserId,
                    hp.getUser().getNickname(),
                    hp.getSeatNumber(),
                    chipCount,
                    hp.getStatus(),
                    hp.getBetTotal(),
                    hp.getWonAmount(),
                    holeCards
            );
        }).toList();

        // Build action responses
        List<HandActionResponse> actionResponses = actions.stream()
                .map(this::toHandActionResponse)
                .toList();

        // Get current player (whose turn it is)
        UUID currentPlayerId = handManager.getCurrentPlayerId(hand.getId());

        return new HandResponse(
                hand.getId(),
                hand.getRoom().getId(),
                hand.getHandNumber(),
                hand.getState(),
                communityCards,
                hand.getPotTotal(),
                playerResponses,
                currentPlayerId,
                actionResponses
        );
    }

    private HandActionResponse toHandActionResponse(HandAction action) {
        return new HandActionResponse(
                action.getUser() != null ? action.getUser().getId() : null,
                action.getActionType(),
                action.getAmount(),
                action.getHandState(),
                action.getSequenceNum(),
                action.getCreatedAt()
        );
    }

    /**
     * Auto-start a new hand in the room (called by the timer service).
     * Skips user validation — just checks that 2+ active players exist.
     */
    @Transactional
    public HandResponse autoStartHand(UUID roomId) {
        Hand hand = handManager.startNewHand(roomId);
        // Use the first player's ID for card visibility in the response
        UUID firstPlayerId = handPlayerRepository.findAllByHandId(hand.getId())
                .stream().findFirst()
                .map(hp -> hp.getUser().getId())
                .orElse(null);
        HandResponse response = toHandResponse(hand, firstPlayerId);
        scheduleTimerIfNeeded(response);
        return response;
    }

    /**
     * Schedule the turn timer for the next player if the hand is still active.
     * Cancel any existing timer if the hand has ended.
     * When a hand reaches SETTLEMENT, schedule auto-start for the next hand.
     */
    private void scheduleTimerIfNeeded(HandResponse response) {
        if (response.currentPlayerId() != null
                && response.state() != HandState.SETTLEMENT
                && response.state() != HandState.SHOWDOWN) {
            turnTimerService.scheduleTurnTimer(
                    response.handId(), response.currentPlayerId(), response.roomId());
        } else {
            turnTimerService.cancelTimer(response.handId());
        }

        // Auto-start next hand after settlement
        if (response.state() == HandState.SETTLEMENT) {
            turnTimerService.scheduleAutoStart(response.roomId());
        }
    }

    /**
     * Parse a comma-separated card code string (e.g. "Ah,Kd,Qs") into a list of strings.
     * Returns an empty list for null or blank input.
     */
    private List<String> parseCardCodes(String cardCodes) {
        if (cardCodes == null || cardCodes.isBlank()) {
            return List.of();
        }
        return Arrays.stream(cardCodes.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();
    }
}
