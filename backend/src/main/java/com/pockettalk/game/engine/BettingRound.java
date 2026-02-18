package com.pockettalk.game.engine;

import com.pockettalk.common.model.ActionType;

import java.util.*;

/**
 * Manages a single betting round in a poker hand.
 *
 * Tracks the current bet, minimum raise, player states, and determines
 * when the round is complete and who acts next.
 *
 * This is a plain POJO (not a Spring bean) because it holds mutable per-hand state.
 * HandManager creates a new instance for each betting round reconstruction.
 */
public class BettingRound {

    /**
     * Per-player state within a single betting round.
     */
    public static class PlayerState {
        private final UUID playerId;
        private final int seatNumber;
        private long chipCount;
        private long betThisRound;
        private boolean hasFolded;
        private boolean isAllIn;
        private boolean hasActed;

        public PlayerState(UUID playerId, int seatNumber, long chipCount) {
            this.playerId = playerId;
            this.seatNumber = seatNumber;
            this.chipCount = chipCount;
            this.betThisRound = 0;
            this.hasFolded = false;
            this.isAllIn = false;
            this.hasActed = false;
        }

        public UUID getPlayerId() { return playerId; }
        public int getSeatNumber() { return seatNumber; }
        public long getChipCount() { return chipCount; }
        public long getBetThisRound() { return betThisRound; }
        public boolean hasFolded() { return hasFolded; }
        public boolean isAllIn() { return isAllIn; }
        public boolean hasActed() { return hasActed; }

        public void setChipCount(long chipCount) { this.chipCount = chipCount; }
        public void setBetThisRound(long betThisRound) { this.betThisRound = betThisRound; }
        public void setHasFolded(boolean hasFolded) { this.hasFolded = hasFolded; }
        public void setIsAllIn(boolean isAllIn) { this.isAllIn = isAllIn; }
        public void setHasActed(boolean hasActed) { this.hasActed = hasActed; }
    }

    private final Map<UUID, PlayerState> players = new LinkedHashMap<>();
    private final List<UUID> seatOrder = new ArrayList<>(); // ordered by seat number
    private long currentBet;
    private long minRaise;
    private long bigBlind;
    private UUID lastAggressor; // the last player who bet/raised
    private int lastActorIndex = -1;

    /**
     * Initialize a new betting round.
     *
     * @param playerStates the players participating, ordered by seat
     * @param currentBet   the current bet to match (0 if no blinds posted yet in this round)
     * @param bigBlind     the big blind amount (used as minimum raise)
     * @param startIndex   the seat-order index of the first player to act
     */
    public void init(List<PlayerState> playerStates, long currentBet, long bigBlind, int startIndex) {
        players.clear();
        seatOrder.clear();

        // Sort by seat number
        List<PlayerState> sorted = playerStates.stream()
                .sorted(Comparator.comparingInt(PlayerState::getSeatNumber))
                .toList();

        for (PlayerState ps : sorted) {
            players.put(ps.getPlayerId(), ps);
            seatOrder.add(ps.getPlayerId());
        }

        this.currentBet = currentBet;
        this.bigBlind = bigBlind;
        this.minRaise = bigBlind;
        this.lastAggressor = null;
        this.lastActorIndex = startIndex >= 0 ? ((startIndex - 1 + seatOrder.size()) % seatOrder.size()) : -1;
    }

    /**
     * Validate whether a player action is legal.
     */
    public boolean isValidAction(UUID playerId, ActionType action, long amount) {
        PlayerState ps = players.get(playerId);
        if (ps == null || ps.hasFolded() || ps.isAllIn()) {
            return false;
        }

        long toCall = currentBet - ps.getBetThisRound();

        return switch (action) {
            case FOLD -> true;
            case CHECK -> toCall == 0;
            case CALL -> toCall > 0 && toCall <= ps.getChipCount();
            case RAISE -> {
                if (toCall >= ps.getChipCount()) {
                    yield false; // can't raise, would need to go all-in
                }
                long raiseAmount = amount - currentBet;
                yield amount > currentBet && raiseAmount >= minRaise
                        && (amount - ps.getBetThisRound()) <= ps.getChipCount();
            }
            case ALL_IN -> ps.getChipCount() > 0;
            default -> false;
        };
    }

    /**
     * Process a player's action, updating round state.
     */
    public void processAction(UUID playerId, ActionType action, long amount) {
        PlayerState ps = players.get(playerId);
        if (ps == null) {
            throw new IllegalArgumentException("Player not in this round: " + playerId);
        }

        switch (action) {
            case FOLD -> {
                ps.setHasFolded(true);
                ps.setHasActed(true);
            }
            case CHECK -> {
                ps.setHasActed(true);
            }
            case CALL -> {
                long toCall = Math.min(currentBet - ps.getBetThisRound(), ps.getChipCount());
                ps.setBetThisRound(ps.getBetThisRound() + toCall);
                ps.setChipCount(ps.getChipCount() - toCall);
                ps.setHasActed(true);
                if (ps.getChipCount() == 0) {
                    ps.setIsAllIn(true);
                }
            }
            case RAISE -> {
                long additionalChips = amount - ps.getBetThisRound();
                long raiseIncrement = amount - currentBet;

                ps.setChipCount(ps.getChipCount() - additionalChips);
                ps.setBetThisRound(amount);
                ps.setHasActed(true);

                // Update minimum raise to be at least the size of this raise
                if (raiseIncrement > minRaise) {
                    minRaise = raiseIncrement;
                }
                currentBet = amount;
                lastAggressor = playerId;

                // All other non-folded, non-all-in players need to act again
                resetActedFlags(playerId);

                if (ps.getChipCount() == 0) {
                    ps.setIsAllIn(true);
                }
            }
            case ALL_IN -> {
                long allInAmount = ps.getChipCount();
                long totalBet = ps.getBetThisRound() + allInAmount;
                ps.setBetThisRound(totalBet);
                ps.setChipCount(0);
                ps.setIsAllIn(true);
                ps.setHasActed(true);

                if (totalBet > currentBet) {
                    long raiseIncrement = totalBet - currentBet;
                    // Only count as a raise (resetting action) if the all-in exceeds
                    // the current bet by at least the minimum raise
                    if (raiseIncrement >= minRaise) {
                        minRaise = raiseIncrement;
                        lastAggressor = playerId;
                        resetActedFlags(playerId);
                    }
                    currentBet = totalBet;
                }
            }
            default -> throw new IllegalArgumentException("Invalid action for betting round: " + action);
        }

        // Update last actor index
        for (int i = 0; i < seatOrder.size(); i++) {
            if (seatOrder.get(i).equals(playerId)) {
                lastActorIndex = i;
                break;
            }
        }
    }

    /**
     * Reset the "has acted" flag for all active players except the specified one.
     * Called when a raise occurs, since other players must act again.
     */
    private void resetActedFlags(UUID excludePlayerId) {
        for (PlayerState ps : players.values()) {
            if (!ps.getPlayerId().equals(excludePlayerId) && !ps.hasFolded() && !ps.isAllIn()) {
                ps.setHasActed(false);
            }
        }
    }

    /**
     * Check if the betting round is complete.
     * The round is complete when all active (not folded, not all-in) players have acted
     * and their bets match the current bet.
     */
    public boolean isRoundComplete() {
        List<PlayerState> active = getActivePlayers();

        // All remaining players are all-in (none can act) → round is complete.
        if (active.isEmpty()) {
            return true;
        }

        // One or more active players remain — each must have acted and matched
        // the current bet before the round is complete. This ensures that when
        // one player goes all-in, the other(s) still get to respond.
        for (PlayerState ps : active) {
            if (!ps.hasActed()) {
                return false;
            }
            if (ps.getBetThisRound() != currentBet) {
                return false;
            }
        }
        return true;
    }

    /**
     * Get the next player to act (clockwise from last actor, skipping folded/all-in).
     *
     * @return the UUID of the next player, or null if round is complete
     */
    public UUID getNextPlayer() {
        if (isRoundComplete()) {
            return null;
        }

        int size = seatOrder.size();
        int startIdx = (lastActorIndex + 1) % size;

        for (int offset = 0; offset < size; offset++) {
            int idx = (startIdx + offset) % size;
            UUID pid = seatOrder.get(idx);
            PlayerState ps = players.get(pid);
            if (!ps.hasFolded() && !ps.isAllIn() && !ps.hasActed()) {
                return pid;
            }
        }

        // Fallback: find first active player who hasn't matched
        for (int offset = 0; offset < size; offset++) {
            int idx = (startIdx + offset) % size;
            UUID pid = seatOrder.get(idx);
            PlayerState ps = players.get(pid);
            if (!ps.hasFolded() && !ps.isAllIn()) {
                return pid;
            }
        }

        return null;
    }

    /**
     * Get players who are still active (not folded and not all-in).
     */
    public List<PlayerState> getActivePlayers() {
        return players.values().stream()
                .filter(ps -> !ps.hasFolded() && !ps.isAllIn())
                .toList();
    }

    /**
     * Get all players who have not folded (active + all-in).
     */
    public List<PlayerState> getNonFoldedPlayers() {
        return players.values().stream()
                .filter(ps -> !ps.hasFolded())
                .toList();
    }

    /**
     * Count players still in the hand (not folded).
     */
    public int countNonFolded() {
        return (int) players.values().stream().filter(ps -> !ps.hasFolded()).count();
    }

    public long getCurrentBet() {
        return currentBet;
    }

    public long getMinRaise() {
        return minRaise;
    }

    public PlayerState getPlayerState(UUID playerId) {
        return players.get(playerId);
    }

    public Map<UUID, PlayerState> getAllPlayerStates() {
        return Collections.unmodifiableMap(players);
    }
}
