package com.pockettalk.game.engine;

import com.pockettalk.auth.entity.User;
import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.common.model.*;
import com.pockettalk.game.entity.*;
import com.pockettalk.game.repository.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Orchestrator for the entire hand lifecycle in a poker game.
 *
 * Manages starting new hands, processing player actions, advancing game state,
 * evaluating showdowns, and settling chip distributions.
 */
@Service
public class HandManager {

    private final RoomRepository roomRepository;
    private final RoomPlayerRepository roomPlayerRepository;
    private final HandRepository handRepository;
    private final HandPlayerRepository handPlayerRepository;
    private final HandActionRepository handActionRepository;

    private final HandEvaluator handEvaluator;
    private final PotCalculator potCalculator;
    private final ActionValidator actionValidator;
    private final ShowdownResolver showdownResolver;
    private final GameStateMachine gameStateMachine;

    public HandManager(RoomRepository roomRepository,
                       RoomPlayerRepository roomPlayerRepository,
                       HandRepository handRepository,
                       HandPlayerRepository handPlayerRepository,
                       HandActionRepository handActionRepository,
                       HandEvaluator handEvaluator,
                       PotCalculator potCalculator,
                       ActionValidator actionValidator,
                       ShowdownResolver showdownResolver,
                       GameStateMachine gameStateMachine) {
        this.roomRepository = roomRepository;
        this.roomPlayerRepository = roomPlayerRepository;
        this.handRepository = handRepository;
        this.handPlayerRepository = handPlayerRepository;
        this.handActionRepository = handActionRepository;
        this.handEvaluator = handEvaluator;
        this.potCalculator = potCalculator;
        this.actionValidator = actionValidator;
        this.showdownResolver = showdownResolver;
        this.gameStateMachine = gameStateMachine;
    }

    /**
     * Start a new hand in the given room.
     *
     * Steps:
     * 1. Find the room and active players.
     * 2. Determine dealer position (rotate from last hand).
     * 3. Create the Hand entity.
     * 4. Create HandPlayer entries and deal hole cards.
     * 5. Post small and big blinds.
     * 6. Set state to PRE_FLOP.
     *
     * @param roomId the room to start a new hand in
     * @return the created Hand
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Hand startNewHand(UUID roomId) {
        Room room = roomRepository.findById(roomId)
                .orElseThrow(() -> new BusinessException("Room not found", HttpStatus.NOT_FOUND, "ROOM_NOT_FOUND"));

        List<RoomPlayer> activePlayers = roomPlayerRepository.findAllByRoomIdAndStatus(roomId, "ACTIVE");
        if (activePlayers.size() < 2) {
            throw new BusinessException(
                    "Need at least 2 active players to start a hand",
                    HttpStatus.BAD_REQUEST, "INSUFFICIENT_PLAYERS");
        }

        // Sort by seat number
        activePlayers.sort(Comparator.comparingInt(RoomPlayer::getSeatNumber));

        // Determine dealer seat (rotate from last hand)
        int dealerSeat = determineDealerSeat(roomId, activePlayers);

        // Determine next hand number
        long handNumber = handRepository.findTopByRoomIdOrderByHandNumberDesc(roomId)
                .map(h -> h.getHandNumber() + 1)
                .orElse(1L);

        // Create the hand
        Hand hand = Hand.builder()
                .room(room)
                .handNumber(handNumber)
                .dealerSeat(dealerSeat)
                .smallBlindAmt(room.getSmallBlind())
                .bigBlindAmt(room.getBigBlind())
                .state(HandState.PRE_FLOP)
                .potTotal(0)
                .build();
        hand = handRepository.save(hand);

        // Shuffle and deal
        Deck deck = new Deck();
        deck.shuffle();

        // Create hand players and deal hole cards
        List<HandPlayer> handPlayers = new ArrayList<>();
        for (RoomPlayer rp : activePlayers) {
            List<Card> holeCards = deck.deal(2);
            String holeCardStr = holeCards.stream().map(Card::toCode).collect(Collectors.joining(","));

            HandPlayer hp = HandPlayer.builder()
                    .hand(hand)
                    .user(rp.getUser())
                    .seatNumber(rp.getSeatNumber())
                    .holeCards(holeCardStr)
                    .status("ACTIVE")
                    .betTotal(0)
                    .wonAmount(0)
                    .build();
            handPlayers.add(hp);
        }
        handPlayerRepository.saveAll(handPlayers);

        // Post blinds
        int sequenceNum = 0;
        sequenceNum = postBlinds(hand, handPlayers, activePlayers, dealerSeat, sequenceNum);

        // Update pot total
        long potTotal = handPlayers.stream().mapToLong(HandPlayer::getBetTotal).sum();
        hand.setPotTotal(potTotal);
        handRepository.save(hand);

        // Update room status
        room.setStatus("PLAYING");
        roomRepository.save(room);

        return hand;
    }

    /**
     * Process a player action within a hand.
     *
     * @param handId   the hand ID
     * @param playerId the acting player's user ID
     * @param action   the action type
     * @param amount   the amount (for RAISE), or 0
     * @return the updated Hand
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Hand processAction(UUID handId, UUID playerId, ActionType action, long amount) {
        Hand hand = handRepository.findByIdForUpdate(handId)
                .orElseThrow(() -> new BusinessException("Hand not found", HttpStatus.NOT_FOUND, "HAND_NOT_FOUND"));

        List<HandPlayer> allPlayers = handPlayerRepository.findAllByHandId(handId);
        HandPlayer handPlayer = allPlayers.stream()
                .filter(hp -> hp.getUser().getId().equals(playerId))
                .findFirst()
                .orElseThrow(() -> new BusinessException(
                        "Player not in this hand", HttpStatus.BAD_REQUEST, "NOT_IN_HAND"));

        // Build the BettingRound state from current hand data
        BettingRound bettingRound = buildBettingRound(hand, allPlayers);

        // Determine current player
        UUID currentPlayerId = bettingRound.getNextPlayer();

        // Validate the action
        actionValidator.validateAction(
                hand, handPlayer, allPlayers, currentPlayerId, playerId,
                action, amount, bettingRound.getCurrentBet(), bettingRound.getMinRaise());

        // Also validate via BettingRound
        if (!bettingRound.isValidAction(playerId, action, amount)) {
            throw new BusinessException(
                    "Action is not valid in current betting context",
                    HttpStatus.BAD_REQUEST, "INVALID_ACTION");
        }

        // Capture the player's bet in this round BEFORE processing the action
        BettingRound.PlayerState preActionState = bettingRound.getPlayerState(playerId);
        long betThisRoundBeforeAction = preActionState.getBetThisRound();

        // Process the action
        bettingRound.processAction(playerId, action, amount);

        // Update HandPlayer status and bet
        BettingRound.PlayerState ps = bettingRound.getPlayerState(playerId);
        updateHandPlayerFromBettingState(handPlayer, ps, action, amount, bettingRound, betThisRoundBeforeAction);

        // Record the action
        int sequenceNum = handActionRepository.countByHandId(handId);
        HandAction handAction = HandAction.builder()
                .hand(hand)
                .user(handPlayer.getUser())
                .actionType(action)
                .amount(resolveActionAmount(action, ps, amount))
                .handState(hand.getState())
                .sequenceNum(sequenceNum)
                .build();
        handActionRepository.save(handAction);

        // Update pot total
        long potTotal = allPlayers.stream().mapToLong(HandPlayer::getBetTotal).sum();
        hand.setPotTotal(potTotal);

        // Check if round/hand should advance
        advanceIfNeeded(hand, allPlayers, bettingRound);

        handRepository.save(hand);
        handPlayerRepository.saveAll(allPlayers);

        return hand;
    }

    /**
     * Get the UUID of the player whose turn it is.
     */
    public UUID getCurrentPlayerId(UUID handId) {
        Hand hand = handRepository.findById(handId).orElse(null);
        if (hand == null) return null;

        List<HandPlayer> allPlayers = handPlayerRepository.findAllByHandId(handId);
        BettingRound bettingRound = buildBettingRound(hand, allPlayers);
        return bettingRound.getNextPlayer();
    }

    // =============================
    // Private helper methods
    // =============================

    /**
     * Determine the dealer seat, rotating from the previous hand's dealer.
     */
    private int determineDealerSeat(UUID roomId, List<RoomPlayer> activePlayers) {
        Optional<Hand> lastHand = handRepository.findTopByRoomIdOrderByHandNumberDesc(roomId);
        if (lastHand.isEmpty()) {
            // First hand - first active player is dealer
            return activePlayers.get(0).getSeatNumber();
        }

        int lastDealerSeat = lastHand.get().getDealerSeat();

        // Find the next active player clockwise from the last dealer
        for (RoomPlayer rp : activePlayers) {
            if (rp.getSeatNumber() > lastDealerSeat) {
                return rp.getSeatNumber();
            }
        }
        // Wrap around to the first player
        return activePlayers.get(0).getSeatNumber();
    }

    /**
     * Post small and big blinds.
     */
    private int postBlinds(Hand hand, List<HandPlayer> handPlayers,
                            List<RoomPlayer> roomPlayers, int dealerSeat, int sequenceNum) {
        // Find SB and BB positions
        // Heads-up: dealer is SB, other is BB
        // 3+: player left of dealer is SB, next is BB
        List<HandPlayer> sorted = handPlayers.stream()
                .sorted(Comparator.comparingInt(HandPlayer::getSeatNumber))
                .toList();

        int dealerIndex = -1;
        for (int i = 0; i < sorted.size(); i++) {
            if (sorted.get(i).getSeatNumber() == dealerSeat) {
                dealerIndex = i;
                break;
            }
        }
        if (dealerIndex == -1) dealerIndex = 0;

        int sbIndex;
        int bbIndex;
        if (sorted.size() == 2) {
            // Heads-up: dealer posts SB
            sbIndex = dealerIndex;
            bbIndex = (dealerIndex + 1) % sorted.size();
        } else {
            sbIndex = (dealerIndex + 1) % sorted.size();
            bbIndex = (dealerIndex + 2) % sorted.size();
        }

        HandPlayer sbPlayer = sorted.get(sbIndex);
        HandPlayer bbPlayer = sorted.get(bbIndex);

        RoomPlayer sbRoomPlayer = findRoomPlayer(roomPlayers, sbPlayer.getUser().getId());
        RoomPlayer bbRoomPlayer = findRoomPlayer(roomPlayers, bbPlayer.getUser().getId());

        // Post small blind
        long sbAmount = Math.min(hand.getSmallBlindAmt(), sbRoomPlayer.getChipCount());
        sbPlayer.setBetTotal(sbAmount);
        sbRoomPlayer.setChipCount(sbRoomPlayer.getChipCount() - sbAmount);
        if (sbRoomPlayer.getChipCount() == 0) {
            sbPlayer.setStatus("ALL_IN");
        }

        HandAction sbAction = HandAction.builder()
                .hand(hand)
                .user(sbPlayer.getUser())
                .actionType(ActionType.SMALL_BLIND)
                .amount(sbAmount)
                .handState(HandState.PRE_FLOP)
                .sequenceNum(sequenceNum++)
                .build();
        handActionRepository.save(sbAction);

        // Post big blind
        long bbAmount = Math.min(hand.getBigBlindAmt(), bbRoomPlayer.getChipCount());
        bbPlayer.setBetTotal(bbAmount);
        bbRoomPlayer.setChipCount(bbRoomPlayer.getChipCount() - bbAmount);
        if (bbRoomPlayer.getChipCount() == 0) {
            bbPlayer.setStatus("ALL_IN");
        }

        HandAction bbAction = HandAction.builder()
                .hand(hand)
                .user(bbPlayer.getUser())
                .actionType(ActionType.BIG_BLIND)
                .amount(bbAmount)
                .handState(HandState.PRE_FLOP)
                .sequenceNum(sequenceNum++)
                .build();
        handActionRepository.save(bbAction);

        // Save updates
        handPlayerRepository.saveAll(List.of(sbPlayer, bbPlayer));
        roomPlayerRepository.saveAll(List.of(sbRoomPlayer, bbRoomPlayer));

        return sequenceNum;
    }

    private RoomPlayer findRoomPlayer(List<RoomPlayer> roomPlayers, UUID userId) {
        return roomPlayers.stream()
                .filter(rp -> rp.getUser().getId().equals(userId))
                .findFirst()
                .orElseThrow(() -> new BusinessException(
                        "Room player not found", HttpStatus.INTERNAL_SERVER_ERROR, "ROOM_PLAYER_NOT_FOUND"));
    }

    /**
     * Build a BettingRound from the current hand state for action validation and processing.
     */
    private BettingRound buildBettingRound(Hand hand, List<HandPlayer> allPlayers) {
        BettingRound bettingRound = new BettingRound();

        List<RoomPlayer> roomPlayers = roomPlayerRepository.findAllByRoomId(hand.getRoom().getId());
        Map<UUID, RoomPlayer> rpMap = roomPlayers.stream()
                .collect(Collectors.toMap(rp -> rp.getUser().getId(), rp -> rp));

        // Get all actions for the current betting round (current hand state)
        List<HandAction> allActions = handActionRepository.findAllByHandIdOrderBySequenceNumAsc(hand.getId());
        List<HandAction> roundActions = allActions.stream()
                .filter(a -> a.getHandState() == hand.getState())
                .toList();

        // Build player states
        List<BettingRound.PlayerState> playerStates = new ArrayList<>();
        for (HandPlayer hp : allPlayers) {
            UUID userId = hp.getUser().getId();
            RoomPlayer rp = rpMap.get(userId);
            long chips = rp != null ? rp.getChipCount() : 0;

            BettingRound.PlayerState ps = new BettingRound.PlayerState(userId, hp.getSeatNumber(), chips);

            if ("FOLDED".equals(hp.getStatus())) {
                ps.setHasFolded(true);
            }
            if ("ALL_IN".equals(hp.getStatus())) {
                ps.setIsAllIn(true);
            }

            playerStates.add(ps);
        }

        // Determine the current bet in this round and min raise
        long currentBet = 0;
        long minRaise = hand.getBigBlindAmt();

        // Calculate bets made in this round from actions
        Map<UUID, Long> roundBets = new LinkedHashMap<>();
        long lastRaiseIncrement = hand.getBigBlindAmt();

        for (HandAction action : roundActions) {
            UUID userId = action.getUser().getId();
            switch (action.getActionType()) {
                case SMALL_BLIND, BIG_BLIND, CALL -> {
                    roundBets.put(userId, roundBets.getOrDefault(userId, 0L) + action.getAmount());
                }
                case RAISE, ALL_IN -> {
                    long prevBet = roundBets.getOrDefault(userId, 0L);
                    long newTotal = action.getAmount();
                    // For raise, the amount stored is the total bet to that level
                    // But if stored as the raise amount, handle both cases
                    if (newTotal > prevBet) {
                        long increment = newTotal - currentBet;
                        if (increment > 0) {
                            lastRaiseIncrement = increment;
                        }
                        roundBets.put(userId, newTotal);
                        if (newTotal > currentBet) {
                            currentBet = newTotal;
                        }
                    } else {
                        roundBets.merge(userId, action.getAmount(), Long::sum);
                        long total = roundBets.get(userId);
                        if (total > currentBet) {
                            long increment = total - currentBet;
                            if (increment > 0) lastRaiseIncrement = increment;
                            currentBet = total;
                        }
                    }
                }
                default -> {} // FOLD, CHECK don't affect bet amounts
            }
        }

        // Apply round bets to player states
        for (BettingRound.PlayerState ps : playerStates) {
            Long bet = roundBets.get(ps.getPlayerId());
            if (bet != null) {
                ps.setBetThisRound(bet);
            }
        }

        minRaise = Math.max(lastRaiseIncrement, hand.getBigBlindAmt());

        // For pre-flop, handle blind bets as the starting current bet
        if (hand.getState() == HandState.PRE_FLOP && roundActions.isEmpty()) {
            // Blinds are posted as part of PRE_FLOP
            // Set current bet from the hand players' bet totals
            currentBet = allPlayers.stream()
                    .mapToLong(HandPlayer::getBetTotal)
                    .max()
                    .orElse(hand.getBigBlindAmt());

            for (BettingRound.PlayerState ps : playerStates) {
                HandPlayer hp = allPlayers.stream()
                        .filter(h -> h.getUser().getId().equals(ps.getPlayerId()))
                        .findFirst().orElse(null);
                if (hp != null) {
                    ps.setBetThisRound(hp.getBetTotal());
                }
            }
        }

        // Determine who has acted in this round
        Set<UUID> actedPlayers = new HashSet<>();
        for (HandAction action : roundActions) {
            if (action.getActionType() != ActionType.SMALL_BLIND
                    && action.getActionType() != ActionType.BIG_BLIND) {
                actedPlayers.add(action.getUser().getId());
            }
        }

        for (BettingRound.PlayerState ps : playerStates) {
            if (actedPlayers.contains(ps.getPlayerId())) {
                ps.setHasActed(true);
            }
        }

        // Determine start index: in pre-flop, player after BB; in other rounds, player after dealer
        List<BettingRound.PlayerState> sortedStates = playerStates.stream()
                .sorted(Comparator.comparingInt(BettingRound.PlayerState::getSeatNumber))
                .toList();

        int startIndex = 0;
        if (!roundActions.isEmpty()) {
            // Start after the last actor
            UUID lastActor = roundActions.get(roundActions.size() - 1).getUser().getId();
            for (int i = 0; i < sortedStates.size(); i++) {
                if (sortedStates.get(i).getPlayerId().equals(lastActor)) {
                    startIndex = i;
                    break;
                }
            }
        }

        bettingRound.init(playerStates, currentBet, hand.getBigBlindAmt(), startIndex);
        return bettingRound;
    }

    /**
     * Update HandPlayer record based on the processed betting action.
     *
     * @param handPlayer               the hand player entity to update
     * @param ps                       the player's state after action processing
     * @param action                   the action performed
     * @param amount                   the requested amount (for RAISE)
     * @param bettingRound             the current betting round
     * @param betThisRoundBeforeAction the player's bet in this round BEFORE the action was processed
     */
    private void updateHandPlayerFromBettingState(HandPlayer handPlayer,
                                                    BettingRound.PlayerState ps,
                                                    ActionType action, long amount,
                                                    BettingRound bettingRound,
                                                    long betThisRoundBeforeAction) {
        if (ps.hasFolded()) {
            handPlayer.setStatus("FOLDED");
        } else if (ps.isAllIn()) {
            handPlayer.setStatus("ALL_IN");
        }

        // The additional chips to deduct = post-action betThisRound - pre-action betThisRound.
        switch (action) {
            case CALL -> {
                long additionalBet = ps.getBetThisRound() - betThisRoundBeforeAction;
                adjustChipsAndBet(handPlayer, additionalBet);
            }
            case RAISE -> {
                long additionalBet = ps.getBetThisRound() - betThisRoundBeforeAction;
                adjustChipsAndBet(handPlayer, additionalBet);
            }
            case ALL_IN -> {
                adjustChipsForAllIn(handPlayer);
            }
            case FOLD, CHECK -> {
                // No chip movement
            }
            default -> {}
        }
    }

    /**
     * Simplified: adjust chips and bet for a standard action.
     */
    private void adjustChipsAndBet(HandPlayer handPlayer, long additionalBet) {
        if (additionalBet <= 0) return;

        RoomPlayer rp = roomPlayerRepository.findByRoomIdAndUserId(
                handPlayer.getHand().getRoom().getId(),
                handPlayer.getUser().getId()).orElse(null);
        if (rp != null) {
            long actual = Math.min(additionalBet, rp.getChipCount());
            handPlayer.setBetTotal(handPlayer.getBetTotal() + actual);
            rp.setChipCount(rp.getChipCount() - actual);
            roomPlayerRepository.save(rp);
        }
    }

    private void adjustChipsForAllIn(HandPlayer handPlayer) {
        RoomPlayer rp = roomPlayerRepository.findByRoomIdAndUserId(
                handPlayer.getHand().getRoom().getId(),
                handPlayer.getUser().getId()).orElse(null);
        if (rp != null) {
            long remaining = rp.getChipCount();
            handPlayer.setBetTotal(handPlayer.getBetTotal() + remaining);
            rp.setChipCount(0);
            roomPlayerRepository.save(rp);
        }
    }

    /**
     * Resolve the amount to record for the action.
     */
    private long resolveActionAmount(ActionType action, BettingRound.PlayerState ps, long requestedAmount) {
        return switch (action) {
            case CALL -> ps.getBetThisRound();
            case RAISE -> requestedAmount;
            case ALL_IN -> ps.getBetThisRound();
            default -> 0;
        };
    }

    /**
     * After processing an action, check if the round or hand needs to advance.
     */
    private void advanceIfNeeded(Hand hand, List<HandPlayer> allPlayers, BettingRound bettingRound) {
        // Check if only one player is left (all others folded)
        long nonFolded = allPlayers.stream()
                .filter(p -> !"FOLDED".equals(p.getStatus()) && !"OUT".equals(p.getStatus()))
                .count();

        if (nonFolded <= 1) {
            // Everyone folded except one - settle immediately
            settleHand(hand, allPlayers);
            return;
        }

        // Check if betting round is complete
        if (bettingRound.isRoundComplete()) {
            HandState nextState = gameStateMachine.transition(hand, hand.getState(), allPlayers);

            if (nextState == HandState.SETTLEMENT) {
                settleHand(hand, allPlayers);
                return;
            }

            if (nextState == HandState.SHOWDOWN) {
                // Deal any remaining community cards first
                dealRemainingCommunityCards(hand);
                performShowdown(hand, allPlayers);
                return;
            }

            // Advance to next betting round
            hand.setState(nextState);

            // Deal community cards for the new state
            dealCommunityCardsForState(hand, nextState);

            // Record the deal action
            ActionType dealAction = switch (nextState) {
                case FLOP -> ActionType.DEAL_FLOP;
                case TURN -> ActionType.DEAL_TURN;
                case RIVER -> ActionType.DEAL_RIVER;
                default -> null;
            };

            if (dealAction != null) {
                int seq = handActionRepository.countByHandId(hand.getId());
                HandAction action = HandAction.builder()
                        .hand(hand)
                        .user(hand.getRoom().getOwner()) // system action attributed to room owner
                        .actionType(dealAction)
                        .amount(0)
                        .handState(nextState)
                        .sequenceNum(seq)
                        .build();
                handActionRepository.save(action);
            }

            // Check if all remaining are ALL_IN after advancing
            long activePlayers = allPlayers.stream()
                    .filter(p -> "ACTIVE".equals(p.getStatus()))
                    .count();

            if (activePlayers <= 1 && nonFolded > 1) {
                // All-in scenario: keep advancing through states
                advanceAllInStates(hand, allPlayers);
            }
        }
    }

    /**
     * When all players are all-in, rapidly advance through deal states to showdown.
     */
    private void advanceAllInStates(Hand hand, List<HandPlayer> allPlayers) {
        while (hand.getState() != HandState.SHOWDOWN && hand.getState() != HandState.SETTLEMENT) {
            HandState nextState = gameStateMachine.transition(hand, hand.getState(), allPlayers);

            if (nextState == HandState.SHOWDOWN) {
                dealRemainingCommunityCards(hand);
                performShowdown(hand, allPlayers);
                return;
            }

            if (nextState == HandState.SETTLEMENT) {
                settleHand(hand, allPlayers);
                return;
            }

            hand.setState(nextState);
            dealCommunityCardsForState(hand, nextState);

            // Record deal action
            ActionType dealAction = switch (nextState) {
                case FLOP -> ActionType.DEAL_FLOP;
                case TURN -> ActionType.DEAL_TURN;
                case RIVER -> ActionType.DEAL_RIVER;
                default -> null;
            };

            if (dealAction != null) {
                int seq = handActionRepository.countByHandId(hand.getId());
                HandAction action = HandAction.builder()
                        .hand(hand)
                        .user(hand.getRoom().getOwner())
                        .actionType(dealAction)
                        .amount(0)
                        .handState(nextState)
                        .sequenceNum(seq)
                        .build();
                handActionRepository.save(action);
            }
        }
    }

    /**
     * Deal community cards for the given state.
     */
    private void dealCommunityCardsForState(Hand hand, HandState state) {
        String existing = hand.getCommunityCards();
        List<Card> existingCards = parseCards(existing);

        // Create a deck and remove known cards
        Deck deck = new Deck();
        deck.shuffle();

        // Collect all known cards (hole cards + community)
        Set<Card> knownCards = new HashSet<>(existingCards);
        List<HandPlayer> players = handPlayerRepository.findAllByHandId(hand.getId());
        for (HandPlayer hp : players) {
            knownCards.addAll(parseCards(hp.getHoleCards()));
        }
        deck.removeAll(knownCards);
        deck.shuffle();

        List<Card> newCards;
        switch (state) {
            case FLOP -> {
                if (existingCards.isEmpty()) {
                    newCards = deck.deal(3);
                } else {
                    return; // Flop already dealt
                }
            }
            case TURN -> {
                if (existingCards.size() == 3) {
                    newCards = deck.deal(1);
                } else {
                    return; // Turn already dealt
                }
            }
            case RIVER -> {
                if (existingCards.size() == 4) {
                    newCards = deck.deal(1);
                } else {
                    return; // River already dealt
                }
            }
            default -> {
                return;
            }
        }

        List<Card> allCommunity = new ArrayList<>(existingCards);
        allCommunity.addAll(newCards);
        hand.setCommunityCards(allCommunity.stream().map(Card::toCode).collect(Collectors.joining(",")));
    }

    /**
     * Deal any remaining community cards (for all-in situations going directly to showdown).
     */
    private void dealRemainingCommunityCards(Hand hand) {
        List<Card> existing = parseCards(hand.getCommunityCards());

        if (existing.size() >= 5) return;

        Deck deck = new Deck();
        deck.shuffle();

        Set<Card> knownCards = new HashSet<>(existing);
        List<HandPlayer> players = handPlayerRepository.findAllByHandId(hand.getId());
        for (HandPlayer hp : players) {
            knownCards.addAll(parseCards(hp.getHoleCards()));
        }
        deck.removeAll(knownCards);
        deck.shuffle();

        int needed = 5 - existing.size();
        List<Card> newCards = deck.deal(needed);

        List<Card> allCommunity = new ArrayList<>(existing);
        allCommunity.addAll(newCards);
        hand.setCommunityCards(allCommunity.stream().map(Card::toCode).collect(Collectors.joining(",")));
    }

    /**
     * Perform the showdown: evaluate hands and determine winners.
     */
    private void performShowdown(Hand hand, List<HandPlayer> allPlayers) {
        hand.setState(HandState.SHOWDOWN);

        List<Card> communityCards = parseCards(hand.getCommunityCards());

        // Build bets for pot calculation
        List<PotCalculator.PlayerBet> bets = allPlayers.stream()
                .filter(p -> !"FOLDED".equals(p.getStatus()))
                .map(p -> new PotCalculator.PlayerBet(p.getUser().getId(), p.getBetTotal()))
                .toList();

        // Also include folded players' bets (they contributed to the pot)
        List<PotCalculator.PlayerBet> allBets = allPlayers.stream()
                .map(p -> new PotCalculator.PlayerBet(p.getUser().getId(), p.getBetTotal()))
                .toList();

        // Resolve showdown
        List<HandPlayer> nonFolded = allPlayers.stream()
                .filter(p -> !"FOLDED".equals(p.getStatus()))
                .toList();

        List<ShowdownResolver.ShowdownResult> results =
                showdownResolver.resolve(nonFolded, communityCards, allBets);

        // Apply results
        for (ShowdownResolver.ShowdownResult result : results) {
            HandPlayer hp = allPlayers.stream()
                    .filter(p -> p.getUser().getId().equals(result.userId()))
                    .findFirst().orElse(null);

            if (hp != null) {
                hp.setWonAmount(result.wonAmount());
                if (result.handResult() != null) {
                    hp.setBestHandRank(result.handResult().rank().getDisplayName());
                    hp.setBestHandCards(result.handResult().bestFive().stream()
                            .map(Card::toCode)
                            .collect(Collectors.joining(",")));
                }
            }
        }

        // Record showdown action
        int seq = handActionRepository.countByHandId(hand.getId());
        HandAction showdownAction = HandAction.builder()
                .hand(hand)
                .user(hand.getRoom().getOwner())
                .actionType(ActionType.SHOWDOWN)
                .amount(0)
                .handState(HandState.SHOWDOWN)
                .sequenceNum(seq)
                .build();
        handActionRepository.save(showdownAction);

        // Move to settlement
        settleHand(hand, allPlayers);
    }

    /**
     * Settle the hand: distribute chips to winners, update room player balances.
     */
    private void settleHand(Hand hand, List<HandPlayer> allPlayers) {
        hand.setState(HandState.SETTLEMENT);
        hand.setEndedAt(Instant.now());

        // If no showdown happened (everyone folded), give pot to last remaining player
        boolean showdownHappened = allPlayers.stream().anyMatch(p -> p.getWonAmount() > 0);
        if (!showdownHappened) {
            HandPlayer winner = allPlayers.stream()
                    .filter(p -> !"FOLDED".equals(p.getStatus()))
                    .findFirst().orElse(null);

            if (winner != null) {
                winner.setWonAmount(hand.getPotTotal());
            }
        }

        // Distribute winnings to room player chip counts
        for (HandPlayer hp : allPlayers) {
            if (hp.getWonAmount() > 0) {
                RoomPlayer rp = roomPlayerRepository.findByRoomIdAndUserId(
                        hand.getRoom().getId(), hp.getUser().getId()).orElse(null);
                if (rp != null) {
                    rp.setChipCount(rp.getChipCount() + hp.getWonAmount());
                    roomPlayerRepository.save(rp);
                }
            }
        }

        // Record settle action
        int seq = handActionRepository.countByHandId(hand.getId());
        HandAction settleAction = HandAction.builder()
                .hand(hand)
                .user(hand.getRoom().getOwner())
                .actionType(ActionType.SETTLE)
                .amount(hand.getPotTotal())
                .handState(HandState.SETTLEMENT)
                .sequenceNum(seq)
                .build();
        handActionRepository.save(settleAction);

        // Mark players with 0 chips as OUT
        List<RoomPlayer> roomPlayers = roomPlayerRepository.findAllByRoomId(hand.getRoom().getId());
        for (RoomPlayer rp : roomPlayers) {
            if (rp.getChipCount() <= 0 && "ACTIVE".equals(rp.getStatus())) {
                rp.setStatus("SITTING_OUT");
                roomPlayerRepository.save(rp);
            }
        }

        // Save all hand player updates
        handPlayerRepository.saveAll(allPlayers);
        handRepository.save(hand);
    }

    /**
     * Parse comma-separated card codes into Card objects.
     */
    private List<Card> parseCards(String cardCodes) {
        if (cardCodes == null || cardCodes.isBlank()) {
            return new ArrayList<>();
        }
        return Arrays.stream(cardCodes.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .map(Card::fromCode)
                .collect(Collectors.toCollection(ArrayList::new));
    }
}
