class WalletDetail {
  const WalletDetail({
    required this.balance,
    required this.bonusBalance,
    required this.incentiveBalance,
    required this.pendingWithdrawals,
    required this.totalWithdrawn,
    this.currency = 'EGP',
  });

  final double balance;
  final double bonusBalance;
  final double incentiveBalance;
  final double pendingWithdrawals;
  final double totalWithdrawn;
  final String currency;

  static const empty = WalletDetail(
    balance: 0,
    bonusBalance: 0,
    incentiveBalance: 0,
    pendingWithdrawals: 0,
    totalWithdrawn: 0,
  );
}
