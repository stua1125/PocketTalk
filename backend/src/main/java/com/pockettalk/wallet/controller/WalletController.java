package com.pockettalk.wallet.controller;

import com.pockettalk.common.dto.ApiResponse;
import com.pockettalk.wallet.dto.TransactionResponse;
import com.pockettalk.wallet.dto.WalletResponse;
import com.pockettalk.wallet.service.WalletService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/wallet")
@RequiredArgsConstructor
public class WalletController {

    private final WalletService walletService;

    @GetMapping("/balance")
    public ApiResponse<WalletResponse> getBalance() {
        UUID userId = getCurrentUserId();
        return ApiResponse.ok(walletService.getBalance(userId));
    }

    @PostMapping("/daily-reward")
    public ApiResponse<WalletResponse> claimDailyReward() {
        UUID userId = getCurrentUserId();
        return ApiResponse.ok(walletService.claimDailyReward(userId));
    }

    @GetMapping("/transactions")
    public ApiResponse<List<TransactionResponse>> getTransactions(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        UUID userId = getCurrentUserId();
        return ApiResponse.ok(walletService.getTransactions(userId, page, size));
    }

    private UUID getCurrentUserId() {
        return UUID.fromString(SecurityContextHolder.getContext().getAuthentication().getName());
    }
}
