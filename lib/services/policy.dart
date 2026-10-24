/// On-chain spending policy mirrored from the ERC-4337 session key.
///
/// The rate limits are enforced twice: here for the UI decision, and by the
/// smart contract when the payment is submitted. This file never signs.
enum PolicyDecision { allow, ownerApproval, reject }

class WalletPolicy {
  const WalletPolicy({
    required this.perTxLimitInr,
    required this.dailyLimitInr,
    required this.spentTodayInr,
    required this.expiresAt,
  });

  final double perTxLimitInr;
  final double dailyLimitInr;
  final double spentTodayInr;
  final DateTime expiresAt;

  double get remainingTodayInr =>
      (dailyLimitInr - spentTodayInr).clamp(0, double.infinity);

  PolicyDecision evaluate(double amountInr, {required DateTime now}) {
    if (amountInr <= 0) return PolicyDecision.reject;
    if (!now.isBefore(expiresAt)) return PolicyDecision.reject;
    if (amountInr > remainingTodayInr) return PolicyDecision.reject;
    if (amountInr > perTxLimitInr) return PolicyDecision.ownerApproval;
    return PolicyDecision.allow;
  }
}
