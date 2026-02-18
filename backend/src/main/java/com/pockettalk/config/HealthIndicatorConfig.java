package com.pockettalk.config;

import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;

import javax.sql.DataSource;
import java.sql.Connection;

/**
 * Custom health indicators for PocketTalk infrastructure and game services.
 * <p>
 * These extend the default Spring Boot Actuator /actuator/health endpoint
 * with application-specific health checks for Redis, RabbitMQ, the database,
 * and the game engine service layer.
 */
@Configuration
public class HealthIndicatorConfig {

    /**
     * Redis health indicator - verifies connectivity by issuing a PING command.
     * Reports UP with connection factory details on success, DOWN with error details on failure.
     */
    @Bean
    public HealthIndicator redisHealthIndicator(RedisConnectionFactory redisConnectionFactory) {
        return () -> {
            try {
                String pong = redisConnectionFactory.getConnection().ping();
                if ("PONG".equals(pong)) {
                    return Health.up()
                            .withDetail("service", "Redis")
                            .withDetail("response", pong)
                            .build();
                }
                return Health.down()
                        .withDetail("service", "Redis")
                        .withDetail("response", pong)
                        .withDetail("reason", "Unexpected PING response")
                        .build();
            } catch (Exception e) {
                return Health.down()
                        .withDetail("service", "Redis")
                        .withDetail("error", e.getClass().getSimpleName())
                        .withDetail("message", e.getMessage())
                        .build();
            }
        };
    }

    /**
     * RabbitMQ health indicator - verifies connectivity by creating and immediately
     * closing a connection. Reports UP on success, DOWN with error details on failure.
     */
    @Bean
    public HealthIndicator rabbitHealthIndicator(ConnectionFactory connectionFactory) {
        return () -> {
            try {
                var connection = connectionFactory.createConnection();
                boolean isOpen = connection.isOpen();
                connection.close();
                if (isOpen) {
                    return Health.up()
                            .withDetail("service", "RabbitMQ")
                            .withDetail("host", connectionFactory.getHost())
                            .withDetail("port", connectionFactory.getPort())
                            .build();
                }
                return Health.down()
                        .withDetail("service", "RabbitMQ")
                        .withDetail("reason", "Connection not open")
                        .build();
            } catch (Exception e) {
                return Health.down()
                        .withDetail("service", "RabbitMQ")
                        .withDetail("error", e.getClass().getSimpleName())
                        .withDetail("message", e.getMessage())
                        .build();
            }
        };
    }

    /**
     * Database health indicator - verifies connectivity by validating a JDBC connection.
     * Uses a 5-second validation timeout. Reports UP with DB product metadata on success.
     */
    @Bean
    public HealthIndicator databaseHealthIndicator(DataSource dataSource) {
        return () -> {
            try (Connection connection = dataSource.getConnection()) {
                boolean valid = connection.isValid(5);
                if (valid) {
                    return Health.up()
                            .withDetail("service", "Database")
                            .withDetail("database", connection.getMetaData().getDatabaseProductName())
                            .withDetail("url", connection.getMetaData().getURL())
                            .build();
                }
                return Health.down()
                        .withDetail("service", "Database")
                        .withDetail("reason", "Connection validation failed")
                        .build();
            } catch (Exception e) {
                return Health.down()
                        .withDetail("service", "Database")
                        .withDetail("error", e.getClass().getSimpleName())
                        .withDetail("message", e.getMessage())
                        .build();
            }
        };
    }

    /**
     * Game engine health indicator - verifies that the core game service layer
     * is operational by checking that the RoomRepository (a critical dependency)
     * is responsive. In a real production setup this could exercise a more
     * comprehensive game-engine readiness check.
     */
    @Bean
    public HealthIndicator gameEngineHealthIndicator(
            com.pockettalk.game.repository.RoomRepository roomRepository) {
        return () -> {
            try {
                // Exercise the repository layer to verify JPA/Hibernate + DB connectivity
                long roomCount = roomRepository.count();
                return Health.up()
                        .withDetail("service", "GameEngine")
                        .withDetail("totalRooms", roomCount)
                        .withDetail("status", "operational")
                        .build();
            } catch (Exception e) {
                return Health.down()
                        .withDetail("service", "GameEngine")
                        .withDetail("error", e.getClass().getSimpleName())
                        .withDetail("message", e.getMessage())
                        .build();
            }
        };
    }
}
