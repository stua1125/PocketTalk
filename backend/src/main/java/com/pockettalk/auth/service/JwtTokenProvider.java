package com.pockettalk.auth.service;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtTokenProvider {

    private final SecretKey key;
    private final long accessTokenExpiration;
    private final long refreshTokenExpiration;

    public JwtTokenProvider(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.access-token-expiry}") long accessTokenExpirySeconds,
            @Value("${jwt.refresh-token-expiry}") long refreshTokenExpirySeconds) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessTokenExpiration = accessTokenExpirySeconds * 1000;
        this.refreshTokenExpiration = refreshTokenExpirySeconds * 1000;
    }

    public String generateAccessToken(UUID userId) {
        return generateToken(userId, accessTokenExpiration, "access");
    }

    public String generateRefreshToken(UUID userId) {
        return generateToken(userId, refreshTokenExpiration, "refresh");
    }

    private String generateToken(UUID userId, long expiration, String type) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + expiration);
        return Jwts.builder()
            .subject(userId.toString())
            .claim("type", type)
            .issuedAt(now)
            .expiration(expiryDate)
            .signWith(key)
            .compact();
    }

    public String getUserIdFromToken(String token) {
        return Jwts.parser()
            .verifyWith(key)
            .build()
            .parseSignedClaims(token)
            .getPayload()
            .getSubject();
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser().verifyWith(key).build().parseSignedClaims(token);
            return true;
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    public boolean isAccessToken(String token) {
        try {
            String type = Jwts.parser().verifyWith(key).build()
                .parseSignedClaims(token).getPayload().get("type", String.class);
            return "access".equals(type);
        } catch (Exception e) {
            return false;
        }
    }
}
