package com.pockettalk.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * Rate limiting configuration using Redis for distributed storage.
 *
 * <p>Limits:
 * <ul>
 *   <li>Auth endpoints: 10 requests/minute per IP</li>
 *   <li>Game action endpoints: 30 requests/minute per user</li>
 *   <li>General API: 100 requests/minute per user</li>
 * </ul>
 */
@Configuration
public class RateLimitConfig {

    @Bean
    public FilterRegistrationBean<RateLimitFilter> rateLimitFilterRegistration(StringRedisTemplate redisTemplate) {
        FilterRegistrationBean<RateLimitFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(new RateLimitFilter(redisTemplate));
        registration.addUrlPatterns("/api/*");
        registration.setOrder(1);
        return registration;
    }

    public static class RateLimitFilter extends OncePerRequestFilter {

        private static final int AUTH_LIMIT = 10;
        private static final int GAME_ACTION_LIMIT = 30;
        private static final int GENERAL_LIMIT = 100;
        private static final Duration WINDOW = Duration.ofMinutes(1);

        private final StringRedisTemplate redisTemplate;
        private final ObjectMapper objectMapper = new ObjectMapper();

        public RateLimitFilter(StringRedisTemplate redisTemplate) {
            this.redisTemplate = redisTemplate;
        }

        @Override
        protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                        FilterChain filterChain) throws ServletException, IOException {
            String path = request.getRequestURI();

            String key;
            int limit;

            if (path.startsWith("/api/v1/auth/")) {
                // Auth endpoints: rate limit by IP
                key = "rate_limit:auth:" + getClientIp(request);
                limit = AUTH_LIMIT;
            } else if (path.matches("/api/v1/hands/.+/actions") && "POST".equalsIgnoreCase(request.getMethod())) {
                // Game action endpoints: rate limit by user
                String userId = getAuthenticatedUserId();
                if (userId == null) {
                    filterChain.doFilter(request, response);
                    return;
                }
                key = "rate_limit:game_action:" + userId;
                limit = GAME_ACTION_LIMIT;
            } else {
                // General API: rate limit by user or IP
                String userId = getAuthenticatedUserId();
                String identifier = userId != null ? userId : getClientIp(request);
                key = "rate_limit:api:" + identifier;
                limit = GENERAL_LIMIT;
            }

            if (!tryAcquire(key, limit)) {
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                response.getWriter().write(objectMapper.writeValueAsString(
                        Map.of("success", false, "error", "TOO_MANY_REQUESTS",
                                "message", "Rate limit exceeded. Please try again later.")));
                return;
            }

            filterChain.doFilter(request, response);
        }

        /**
         * Attempt to acquire a rate limit token using Redis INCR with expiry.
         * Uses a sliding window counter per minute.
         */
        private boolean tryAcquire(String key, int limit) {
            try {
                Long count = redisTemplate.opsForValue().increment(key);
                if (count != null && count == 1) {
                    redisTemplate.expire(key, WINDOW.toSeconds(), TimeUnit.SECONDS);
                }
                return count != null && count <= limit;
            } catch (Exception e) {
                // If Redis is unavailable, allow the request (fail open)
                logger.warn("Rate limiting unavailable (Redis error), allowing request: " + e.getMessage());
                return true;
            }
        }

        private String getClientIp(HttpServletRequest request) {
            String xForwardedFor = request.getHeader("X-Forwarded-For");
            if (xForwardedFor != null && !xForwardedFor.isBlank()) {
                return xForwardedFor.split(",")[0].trim();
            }
            return request.getRemoteAddr();
        }

        private String getAuthenticatedUserId() {
            Authentication auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getPrincipal())) {
                return auth.getName();
            }
            return null;
        }
    }
}
