package com.pockettalk.game.engine;

import com.pockettalk.game.engine.PotCalculator.PlayerBet;
import com.pockettalk.game.engine.PotCalculator.Pot;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class PotCalculatorTest {

    private PotCalculator calculator;

    private final UUID player1 = UUID.randomUUID();
    private final UUID player2 = UUID.randomUUID();
    private final UUID player3 = UUID.randomUUID();
    private final UUID player4 = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        calculator = new PotCalculator();
    }

    // -------------------------------------------------------
    // Main pot calculation (2 players, simple case)
    // -------------------------------------------------------

    @Test
    void twoPlayers_equalBets_onePot() {
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 100),
                new PlayerBet(player2, 100)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        assertEquals(1, pots.size());
        assertEquals(200, pots.get(0).amount());
        assertTrue(pots.get(0).eligiblePlayers().contains(player1));
        assertTrue(pots.get(0).eligiblePlayers().contains(player2));
    }

    @Test
    void twoPlayers_unequalBets_twoPots() {
        // Player1 goes all-in for 50, Player2 bets 100
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 50),
                new PlayerBet(player2, 100)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        assertEquals(2, pots.size());

        // Main pot: both contribute 50 each = 100
        Pot mainPot = pots.get(0);
        assertEquals(100, mainPot.amount());
        assertTrue(mainPot.eligiblePlayers().contains(player1));
        assertTrue(mainPot.eligiblePlayers().contains(player2));

        // Side pot: only player2's remaining 50
        Pot sidePot = pots.get(1);
        assertEquals(50, sidePot.amount());
        assertFalse(sidePot.eligiblePlayers().contains(player1));
        assertTrue(sidePot.eligiblePlayers().contains(player2));
    }

    // -------------------------------------------------------
    // Side pot with all-in (3 players, 1 all-in with less chips)
    // -------------------------------------------------------

    @Test
    void threePlayers_oneAllInSmaller_twoPotsCreated() {
        // Player1 all-in 30, Player2 bets 100, Player3 bets 100
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 30),
                new PlayerBet(player2, 100),
                new PlayerBet(player3, 100)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        assertEquals(2, pots.size());

        // Main pot: all 3 contribute 30 each = 90
        Pot mainPot = pots.get(0);
        assertEquals(90, mainPot.amount());
        assertEquals(3, mainPot.eligiblePlayers().size());
        assertTrue(mainPot.eligiblePlayers().contains(player1));
        assertTrue(mainPot.eligiblePlayers().contains(player2));
        assertTrue(mainPot.eligiblePlayers().contains(player3));

        // Side pot: player2 and player3 contribute (100-30)=70 each = 140
        Pot sidePot = pots.get(1);
        assertEquals(140, sidePot.amount());
        assertEquals(2, sidePot.eligiblePlayers().size());
        assertFalse(sidePot.eligiblePlayers().contains(player1));
        assertTrue(sidePot.eligiblePlayers().contains(player2));
        assertTrue(sidePot.eligiblePlayers().contains(player3));
    }

    // -------------------------------------------------------
    // Multiple side pots (4 players, 2 all-ins at different amounts)
    // -------------------------------------------------------

    @Test
    void fourPlayers_twoAllInsAtDifferentAmounts_threePotsCreated() {
        // Player1 all-in 20, Player2 all-in 50,
        // Player3 bets 100, Player4 bets 100
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 20),
                new PlayerBet(player2, 50),
                new PlayerBet(player3, 100),
                new PlayerBet(player4, 100)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        assertEquals(3, pots.size());

        // Main pot: all 4 contribute 20 each = 80
        Pot mainPot = pots.get(0);
        assertEquals(80, mainPot.amount());
        assertEquals(4, mainPot.eligiblePlayers().size());

        // Side pot 1: player2, player3, player4 contribute (50-20)=30 each = 90
        Pot sidePot1 = pots.get(1);
        assertEquals(90, sidePot1.amount());
        assertEquals(3, sidePot1.eligiblePlayers().size());
        assertFalse(sidePot1.eligiblePlayers().contains(player1));

        // Side pot 2: player3, player4 contribute (100-50)=50 each = 100
        Pot sidePot2 = pots.get(2);
        assertEquals(100, sidePot2.amount());
        assertEquals(2, sidePot2.eligiblePlayers().size());
        assertFalse(sidePot2.eligiblePlayers().contains(player1));
        assertFalse(sidePot2.eligiblePlayers().contains(player2));
        assertTrue(sidePot2.eligiblePlayers().contains(player3));
        assertTrue(sidePot2.eligiblePlayers().contains(player4));
    }

    @Test
    void fourPlayers_totalAmountAcrossAllPots_matchesTotalBets() {
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 20),
                new PlayerBet(player2, 50),
                new PlayerBet(player3, 100),
                new PlayerBet(player4, 100)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        long totalPotAmount = pots.stream().mapToLong(Pot::amount).sum();
        long totalBets = bets.stream().mapToLong(PlayerBet::betAmount).sum();

        assertEquals(totalBets, totalPotAmount,
                "Sum of all pots must equal sum of all bets");
    }

    // -------------------------------------------------------
    // Empty bet list
    // -------------------------------------------------------

    @Test
    void emptyBetList_returnsNoPots() {
        List<Pot> pots = calculator.calculatePots(List.of());
        assertTrue(pots.isEmpty());
    }

    @Test
    void nullBetList_returnsNoPots() {
        List<Pot> pots = calculator.calculatePots(null);
        assertTrue(pots.isEmpty());
    }

    @Test
    void allZeroBets_returnsNoPots() {
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 0),
                new PlayerBet(player2, 0)
        );

        List<Pot> pots = calculator.calculatePots(bets);
        assertTrue(pots.isEmpty());
    }

    // -------------------------------------------------------
    // All players bet same amount
    // -------------------------------------------------------

    @Test
    void allPlayersSameAmount_singlePot() {
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 100),
                new PlayerBet(player2, 100),
                new PlayerBet(player3, 100)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        assertEquals(1, pots.size());
        assertEquals(300, pots.get(0).amount());
        assertEquals(3, pots.get(0).eligiblePlayers().size());
    }

    @Test
    void allPlayersSameAmount_fourPlayers_singlePot() {
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 200),
                new PlayerBet(player2, 200),
                new PlayerBet(player3, 200),
                new PlayerBet(player4, 200)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        assertEquals(1, pots.size());
        assertEquals(800, pots.get(0).amount());
        assertEquals(4, pots.get(0).eligiblePlayers().size());
    }

    // -------------------------------------------------------
    // Additional edge cases
    // -------------------------------------------------------

    @Test
    void singlePlayer_singlePot() {
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 100)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        assertEquals(1, pots.size());
        assertEquals(100, pots.get(0).amount());
        assertTrue(pots.get(0).eligiblePlayers().contains(player1));
    }

    @Test
    void threePlayers_twoAllInAtSameAmount() {
        // Player1 and Player2 all-in for 50, Player3 bets 100
        List<PlayerBet> bets = List.of(
                new PlayerBet(player1, 50),
                new PlayerBet(player2, 50),
                new PlayerBet(player3, 100)
        );

        List<Pot> pots = calculator.calculatePots(bets);

        assertEquals(2, pots.size());

        // Main pot: all 3 contribute 50 each = 150
        assertEquals(150, pots.get(0).amount());
        assertEquals(3, pots.get(0).eligiblePlayers().size());

        // Side pot: player3's extra 50
        assertEquals(50, pots.get(1).amount());
        assertEquals(1, pots.get(1).eligiblePlayers().size());
        assertTrue(pots.get(1).eligiblePlayers().contains(player3));
    }
}
