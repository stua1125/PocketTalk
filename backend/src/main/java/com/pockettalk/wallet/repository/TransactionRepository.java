package com.pockettalk.wallet.repository;

import com.pockettalk.wallet.entity.Transaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TransactionRepository extends JpaRepository<Transaction, UUID> {
    List<Transaction> findAllByUserIdOrderByCreatedAtDesc(UUID userId);
    Page<Transaction> findAllByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
    List<Transaction> findAllByUserIdAndTypeOrderByCreatedAtDesc(UUID userId, String type);
}
