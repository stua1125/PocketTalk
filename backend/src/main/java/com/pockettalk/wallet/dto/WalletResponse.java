package com.pockettalk.wallet.dto;

import java.time.Instant;

public record WalletResponse(
    long balance,
    boolean dailyRewardAvailable,
    Instant lastDailyRewardAt
) {}
