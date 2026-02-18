package com.pockettalk.wallet.service;

import com.pockettalk.auth.entity.User;
import com.pockettalk.auth.repository.UserRepository;
import com.pockettalk.common.exception.BusinessException;
import com.pockettalk.wallet.dto.TransactionResponse;
import com.pockettalk.wallet.dto.WalletResponse;
import com.pockettalk.wallet.entity.Transaction;
import com.pockettalk.wallet.repository.TransactionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class WalletService {

    private final UserRepository userRepository;
    private final TransactionRepository transactionRepository;

    private static final long DAILY_REWARD_AMOUNT = 1000L;

    @Transactional(readOnly = true)
    public WalletResponse getBalance(UUID userId) {
        User user = findUser(userId);
        boolean dailyAvailable = isDailyRewardAvailable(user);
        return new WalletResponse(user.getChipBalance(), dailyAvailable, user.getDailyRewardAt());
    }

    @Transactional
    public WalletResponse claimDailyReward(UUID userId) {
        User user = findUserForUpdate(userId);

        if (!isDailyRewardAvailable(user)) {
            throw new BusinessException("Daily reward already claimed", HttpStatus.BAD_REQUEST, "DAILY_REWARD_CLAIMED");
        }

        user.setChipBalance(user.getChipBalance() + DAILY_REWARD_AMOUNT);
        user.setDailyRewardAt(Instant.now());
        userRepository.save(user);

        recordTransaction(user, "DAILY_REWARD", DAILY_REWARD_AMOUNT, user.getChipBalance(), null, "Daily reward");

        return new WalletResponse(user.getChipBalance(), false, user.getDailyRewardAt());
    }

    @Transactional(readOnly = true)
    public List<TransactionResponse> getTransactions(UUID userId, int page, int size) {
        Page<Transaction> txPage = transactionRepository.findAllByUserIdOrderByCreatedAtDesc(
                userId, PageRequest.of(page, size));
        return txPage.getContent().stream().map(TransactionResponse::from).toList();
    }

    private boolean isDailyRewardAvailable(User user) {
        if (user.getDailyRewardAt() == null) return true;
        return Instant.now().isAfter(user.getDailyRewardAt().plus(Duration.ofHours(24)));
    }

    private void recordTransaction(User user, String type, long amount, long balanceAfter,
                                   UUID referenceId, String description) {
        Transaction tx = Transaction.builder()
                .user(user)
                .type(type)
                .amount(amount)
                .balanceAfter(balanceAfter)
                .referenceId(referenceId)
                .description(description)
                .build();
        transactionRepository.save(tx);
    }

    private User findUser(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException("User not found", HttpStatus.NOT_FOUND, "USER_NOT_FOUND"));
    }

    private User findUserForUpdate(UUID userId) {
        return userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new BusinessException("User not found", HttpStatus.NOT_FOUND, "USER_NOT_FOUND"));
    }
}
