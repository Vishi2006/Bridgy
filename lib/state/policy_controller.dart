import 'package:flutter/foundation.dart';

import '../services/policy.dart';
import '../services/wallet_service.dart';

/// Holds the spending policy shown in the UI.
///
/// The backend ledger is the only source. There is no local policy fallback:
/// a failed read or write stores the exact error and the UI shows it.
class PolicyController extends ChangeNotifier {
  PolicyController();

  static final PolicyController instance = PolicyController();

  double perTxLimitInr = 200;
  double dailyLimitInr = 500;
  double spentTodayInr = 0;
  DateTime expiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  String smartWalletAddress = 'pending';
  bool isSmartAccountLive = false;

  String syncStatus = 'not loaded';
  String? error;

  WalletPolicy get policy => WalletPolicy(
    perTxLimitInr: perTxLimitInr,
    dailyLimitInr: dailyLimitInr,
    spentTodayInr: spentTodayInr,
    expiresAt: expiresAt,
  );

  PolicyDecision evaluate(double amountInr) =>
      policy.evaluate(amountInr, now: DateTime.now());

  Future<void> load() async {
    try {
      final status = await WalletService.getStatus();
      _apply(status);
      syncStatus = 'synced (backend)';
      error = null;
    } on Exception catch (failure) {
      syncStatus = 'backend unavailable';
      error = failure.toString();
    }
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final status = await WalletService.updatePolicy(
        perTxLimitInr: perTxLimitInr,
        dailyLimitInr: dailyLimitInr,
      );
      _apply(status);
      syncStatus = 'saved (backend)';
      error = null;
      notifyListeners();
    } on Exception catch (failure) {
      syncStatus = 'save failed';
      error = failure.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> renewSession() async {
    try {
      await WalletService.renewSession();
      await load();
      return true;
    } on Exception catch (failure) {
      syncStatus = 'renew failed';
      error = failure.toString();
      notifyListeners();
      return false;
    }
  }

  void setPerTxLimit(double value) {
    perTxLimitInr = value;
    notifyListeners();
  }

  void setDailyLimit(double value) {
    dailyLimitInr = value;
    notifyListeners();
  }

  void setExpiry(DateTime value) {
    expiresAt = value;
    notifyListeners();
  }

  void _apply(WalletStatus status) {
    perTxLimitInr = status.perTxLimitInr;
    dailyLimitInr = status.dailyLimitInr;
    spentTodayInr = status.spentTodayInr;
    expiresAt = status.policyExpiry;
    smartWalletAddress = status.smartAccountAddress;
    isSmartAccountLive = status.isLive;
  }
}
