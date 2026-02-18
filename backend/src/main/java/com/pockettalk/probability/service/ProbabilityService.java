package com.pockettalk.probability.service;

import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.common.model.Card;
import com.pockettalk.common.model.HandRank;
import com.pockettalk.probability.MonteCarloSimulator;
import com.pockettalk.probability.SimulationResult;
import com.pockettalk.probability.dto.ProbabilityRequest;
import com.pockettalk.probability.dto.ProbabilityResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Service that validates probability requests, delegates to the Monte Carlo
 * simulator, and caches results in Redis.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProbabilityService {

    private static final Duration CACHE_TTL = Duration.ofHours(1);
    private static final String CACHE_PREFIX = "prob:";

    private final MonteCarloSimulator simulator;
    private final RedisTemplate<String, Object> redisTemplate;

    /**
     * Calculate win/tie/loss probabilities for the given poker situation.
     * Results are cached in Redis for 1 hour.
     */
    public ProbabilityResponse calculate(ProbabilityRequest request) {
        validate(request);

        List<Card> holeCards = parseCards(request.holeCards());
        List<Card> communityCards = parseCards(request.communityCards());

        String cacheKey = buildCacheKey(holeCards, communityCards, request.numOpponents());

        // Try cache first
        Object cached = redisTemplate.opsForValue().get(cacheKey);
        if (cached instanceof ProbabilityResponse cachedResponse) {
            log.debug("Cache hit for key: {}", cacheKey);
            return cachedResponse;
        }

        log.debug("Cache miss for key: {}, running simulation", cacheKey);
        SimulationResult result = simulator.simulate(holeCards, communityCards, request.numOpponents());

        ProbabilityResponse response = toResponse(result);

        // Cache the result
        redisTemplate.opsForValue().set(cacheKey, response, CACHE_TTL);

        return response;
    }

    /**
     * Parse a user-facing card string into the internal Card model.
     * Accepted formats:
     *   - 2-char: rank + suit initial, e.g. "AS", "Kh", "9d"
     *   - 3-char for 10: "10S", "10h"
     * The suit initial is case-insensitive.
     */
    private Card parseCard(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new BusinessException("Card string must not be blank", HttpStatus.BAD_REQUEST, "INVALID_CARD");
        }

        String trimmed = raw.trim();
        String rankCode;
        String suitCode;

        if (trimmed.length() == 3 && trimmed.startsWith("10")) {
            // "10S" / "10h" -> rank code "T", suit code "s"/"h"
            rankCode = "T";
            suitCode = trimmed.substring(2).toLowerCase();
        } else if (trimmed.length() == 2) {
            rankCode = trimmed.substring(0, 1).toUpperCase();
            suitCode = trimmed.substring(1).toLowerCase();
        } else {
            throw new BusinessException(
                    "Invalid card format: '" + raw + "'. Expected 2-3 characters (e.g. AS, Kh, 10S).",
                    HttpStatus.BAD_REQUEST, "INVALID_CARD");
        }

        try {
            return Card.fromCode(rankCode + suitCode);
        } catch (IllegalArgumentException e) {
            throw new BusinessException(
                    "Invalid card: '" + raw + "'. " + e.getMessage(),
                    HttpStatus.BAD_REQUEST, "INVALID_CARD");
        }
    }

    private List<Card> parseCards(List<String> rawCards) {
        if (rawCards == null || rawCards.isEmpty()) {
            return List.of();
        }
        return rawCards.stream()
                .map(this::parseCard)
                .collect(Collectors.toList());
    }

    private void validate(ProbabilityRequest request) {
        if (request.holeCards() == null || request.holeCards().size() != 2) {
            throw new BusinessException(
                    "Exactly 2 hole cards are required",
                    HttpStatus.BAD_REQUEST, "INVALID_HOLE_CARDS");
        }

        List<String> communityCards = request.communityCards() != null ? request.communityCards() : List.of();
        if (communityCards.size() > 5) {
            throw new BusinessException(
                    "Community cards must be 0-5 cards, got " + communityCards.size(),
                    HttpStatus.BAD_REQUEST, "INVALID_COMMUNITY_CARDS");
        }

        if (request.numOpponents() < 1 || request.numOpponents() > 9) {
            throw new BusinessException(
                    "Number of opponents must be between 1 and 9",
                    HttpStatus.BAD_REQUEST, "INVALID_OPPONENTS");
        }

        // Check total card count feasibility: 2 (hero) + community + 2*opponents <= 52
        int totalCardsNeeded = 2 + 5 + (request.numOpponents() * 2);
        if (totalCardsNeeded > 52) {
            throw new BusinessException(
                    "Too many opponents for a single deck",
                    HttpStatus.BAD_REQUEST, "TOO_MANY_OPPONENTS");
        }

        // Parse all cards to check for duplicates
        List<Card> allCards = new ArrayList<>();
        allCards.addAll(parseCards(request.holeCards()));
        allCards.addAll(parseCards(communityCards));

        Set<Card> uniqueCards = new HashSet<>(allCards);
        if (uniqueCards.size() != allCards.size()) {
            throw new BusinessException(
                    "Duplicate cards detected in input",
                    HttpStatus.BAD_REQUEST, "DUPLICATE_CARDS");
        }
    }

    private ProbabilityResponse toResponse(SimulationResult result) {
        Map<String, Double> handDistribution = new LinkedHashMap<>();
        for (HandRank rank : HandRank.values()) {
            double prob = result.handDistribution().getOrDefault(rank, 0.0);
            handDistribution.put(rank.getDisplayName(), prob);
        }

        return new ProbabilityResponse(
                result.winProbability(),
                result.tieProbability(),
                result.lossProbability(),
                handDistribution,
                result.simulationCount()
        );
    }

    /**
     * Build a deterministic cache key from the given cards and opponent count.
     * Cards are sorted by their code representation to ensure consistent keys
     * regardless of input order.
     */
    private String buildCacheKey(List<Card> holeCards, List<Card> communityCards, int opponents) {
        String holePart = holeCards.stream()
                .map(Card::toCode)
                .sorted()
                .collect(Collectors.joining(","));

        String communityPart = communityCards.stream()
                .map(Card::toCode)
                .sorted()
                .collect(Collectors.joining(","));

        return CACHE_PREFIX + holePart + ":" + communityPart + ":" + opponents;
    }
}
