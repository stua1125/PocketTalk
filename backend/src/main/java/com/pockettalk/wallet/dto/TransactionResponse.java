package com.pockettalk.wallet.dto;

import com.pockettalk.wallet.entity.Transaction;

import java.time.Instant;
import java.util.UUID;

public record TransactionResponse(
    UUID id,
    String type,
    long amount,
    long balanceAfter,
    String description,
    Instant createdAt
) {
    public static TransactionResponse from(Transaction tx) {
        return new TransactionResponse(
            tx.getId(),
            tx.getType(),
            tx.getAmount(),
            tx.getBalanceAfter(),
            tx.getDescription(),
            tx.getCreatedAt()
        );
    }
}
