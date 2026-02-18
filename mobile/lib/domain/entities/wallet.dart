class WalletInfo {
  final int balance;
  final bool dailyRewardAvailable;
  final DateTime? lastDailyRewardAt;

  const WalletInfo({
    required this.balance,
    required this.dailyRewardAvailable,
    this.lastDailyRewardAt,
  });

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      balance: json['balance'] as int? ?? 0,
      dailyRewardAvailable: json['dailyRewardAvailable'] as bool? ?? false,
      lastDailyRewardAt: json['lastDailyRewardAt'] != null
          ? DateTime.parse(json['lastDailyRewardAt'] as String)
          : null,
    );
  }
}

class WalletTransaction {
  final String id;
  final String type;
  final int amount;
  final int balanceAfter;
  final String? description;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: json['amount'] as int,
      balanceAfter: json['balanceAfter'] as int,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
