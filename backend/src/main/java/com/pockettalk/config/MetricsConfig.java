package com.pockettalk.config;

import com.pockettalk.game.repository.RoomRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.binder.MeterBinder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Custom metrics configuration for PocketTalk game monitoring.
 * <p>
 * Registers Micrometer counters, gauges, and timers that track
 * poker-specific operational metrics exposed via the Prometheus endpoint.
 */
@Configuration
public class MetricsConfig {

    /**
     * Tracks the number of WebSocket sessions currently connected.
     * Intended to be incremented/decremented by WebSocket lifecycle handlers.
     */
    private final AtomicLong connectedWebSocketSessions = new AtomicLong(0);

    // --- Counters ---

    @Bean
    public Counter handsStartedCounter(MeterRegistry registry) {
        return Counter.builder("hands.started.total")
                .description("Total number of poker hands started")
                .tag("type", "hand_lifecycle")
                .register(registry);
    }

    @Bean
    public Counter actionsProcessedCounter(MeterRegistry registry) {
        return Counter.builder("actions.processed.total")
                .description("Total number of player actions processed (fold, check, call, raise, all-in)")
                .tag("type", "player_action")
                .register(registry);
    }

    @Bean
    public Counter handsCompletedCounter(MeterRegistry registry) {
        return Counter.builder("hands.completed.total")
                .description("Total number of poker hands completed (reached showdown or early settlement)")
                .tag("type", "hand_lifecycle")
                .register(registry);
    }

    // --- Gauges ---

    @Bean
    public MeterBinder activeRoomsGauge(RoomRepository roomRepository) {
        return registry -> Gauge.builder("active.rooms", () ->
                        roomRepository.findByStatusIn(List.of("WAITING", "PLAYING")).size())
                .description("Number of rooms currently in WAITING or PLAYING status")
                .register(registry);
    }

    @Bean
    public MeterBinder connectedWebSocketSessionsGauge() {
        return registry -> Gauge.builder("connected.websocket.sessions", connectedWebSocketSessions, AtomicLong::get)
                .description("Number of currently connected WebSocket sessions")
                .register(registry);
    }

    /**
     * Returns the AtomicLong backing the WebSocket session gauge.
     * Other components (e.g. WebSocket interceptors) can inject this bean
     * to increment/decrement the count.
     */
    @Bean
    public AtomicLong webSocketSessionCounter() {
        return connectedWebSocketSessions;
    }

    // --- Timers ---

    @Bean
    public Timer handProcessingTimer(MeterRegistry registry) {
        return Timer.builder("hand.processing.time")
                .description("Time taken to process an entire hand from start to settlement")
                .tag("type", "hand_lifecycle")
                .publishPercentileHistogram()
                .register(registry);
    }

    @Bean
    public Timer actionProcessingTimer(MeterRegistry registry) {
        return Timer.builder("action.processing.time")
                .description("Time taken to validate and process a single player action")
                .tag("type", "player_action")
                .publishPercentileHistogram()
                .register(registry);
    }
}
