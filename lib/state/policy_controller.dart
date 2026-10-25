import 'package:flutter/foundation.dart';

import '../services/backend.dart';
import '../services/policy.dart';
import '../services/wallet_service.dart';

/// Holds the spending policy shown in the UI and mirrored to the Express backend
/// and Supabase's `wallets` row when configured.
///
/// This is the display-side copy. The authoritative limits live in the
/// ERC-4337 ZeroDev Kernel session key on Base Sepolia.
class PolicyController extends ChangeNotifier {
  PolicyController();

  static final PolicyController instance = PolicyController();

  double perTxLimitInr = 200;
  double dailyLimitInr = 500;
  double spentTodayInr = 0;
  DateTime expiresAt = DateTime.now().add(const Duration(hours: 24));

  String smartWalletAddress = '0x88F7c64a8523A9C830Da4c1F3235b62b66eCe4eA';
  String agentSessionAddress = '0x...';
  bool isSmartAccountLive = false;

  String syncStatus = 'local only';
  Object? _rowId;

  WalletPolicy get policy => WalletPolicy(
    perTxLimitInr: perTxLimitInr,
    dailyLimitInr: dailyLimitInr,
    spentTodayInr: spentTodayInr,
    expiresAt: expiresAt,
  );

  PolicyDecision evaluate(double amountInr) =>
      policy.evaluate(amountInr, now: DateTime.now());

  Future<void> load() async {
    // 1. Fetch live status from Express Backend
    try {
      final backendStatus = await WalletService.getStatus();
      if (backendStatus != null) {
        smartWalletAddress =
            backendStatus['smartAccountAddress'] as String? ?? smartWalletAddress;
        agentSessionAddress =
            backendStatus['agentSessionAddress'] as String? ?? agentSessionAddress;
        isSmartAccountLive = backendStatus['isLive'] == true;

        final policyData = backendStatus['policy'] as Map<String, dynamic>?;
        if (policyData != null) {
          perTxLimitInr = _toDouble(policyData['perTxLimitInr'], perTxLimitInr);
          dailyLimitInr = _toDouble(policyData['dailyLimitInr'], dailyLimitInr);
          spentTodayInr = _toDouble(policyData['spentTodayInr'], spentTodayInr);
          final untilSec = policyData['validUntilTimestamp'];
          if (untilSec is num) {
            expiresAt = DateTime.fromMillisecondsSinceEpoch(
              (untilSec * 1000).toInt(),
            );
          }
        }
        syncStatus = 'synced (backend)';
      }
    } catch (e) {
      debugPrint('[PolicyController] Backend sync note: $e');
    }

    // 2. Fetch from Supabase if configured
    final client = BridgyBackend.client;
    if (client != null) {
      try {
        final rows = await client
            .from('wallets')
            .select()
            .order('id')
            .limit(1);
        if (rows.isNotEmpty) {
          final row = rows.first;
          _rowId = row['id'];
          perTxLimitInr = _toDouble(row['per_tx_limit_inr'], perTxLimitInr);
          dailyLimitInr = _toDouble(row['daily_limit_inr'], dailyLimitInr);
          spentTodayInr = _toDouble(row['spent_today_inr'], spentTodayInr);
          final expiry = DateTime.tryParse('${row['policy_expiry']}');
          if (expiry != null) expiresAt = expiry.toLocal();
          syncStatus = 'synced (cloud)';
        }
      } catch (e) {
        debugPrint('[PolicyController] Supabase load skipped: $e');
      }
    }

    notifyListeners();
  }

  Future<void> save() async {
    // Backend is the authoritative policy store for the running agent.
    final backendSaved = await WalletService.updatePolicy(
      perTxLimitInr: perTxLimitInr,
      dailyLimitInr: dailyLimitInr,
    );
    syncStatus = backendSaved ? 'saved (backend)' : 'backend unavailable';

    // Supabase is a best-effort mirror. A missing table or RLS failure must not
    // hide the fact that the backend already accepted the policy.
    final client = BridgyBackend.client;
    if (client != null) {
      final payload = {
        'per_tx_limit_inr': perTxLimitInr,
        'daily_limit_inr': dailyLimitInr,
        'spent_today_inr': spentTodayInr,
        'policy_expiry': expiresAt.toUtc().toIso8601String(),
      };
      try {
        if (_rowId != null) {
          await client.from('wallets').update(payload).eq('id', _rowId!);
        } else {
          final inserted = await client
              .from('wallets')
              .insert({'smart_wallet_address': smartWalletAddress, ...payload})
              .select('id')
              .single();
          _rowId = inserted['id'];
        }
        syncStatus = 'saved';
      } catch (e) {
        debugPrint('[PolicyController] Supabase mirror skipped: $e');
      }
    }

    notifyListeners();
  }

  Future<bool> renewSession() async {
    final ok = await WalletService.renewSession();
    expiresAt = DateTime.now().add(const Duration(hours: 24));
    notifyListeners();
    return ok;
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

  static double _toDouble(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;
}
