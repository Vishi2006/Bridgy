import 'package:flutter/foundation.dart';

import '../services/backend.dart';
import '../services/policy.dart';

/// Holds the spending policy shown in the UI and mirrored to Supabase's
/// `wallets` row when a backend is configured.
///
/// This is the display-side copy. The authoritative limits live in the
/// ERC-4337 session key; nothing here can authorise a payment on its own.
class PolicyController extends ChangeNotifier {
  PolicyController();

  static final PolicyController instance = PolicyController();

  double perTxLimitInr = 200;
  double dailyLimitInr = 500;
  double spentTodayInr = 0;
  DateTime expiresAt = DateTime.now().add(const Duration(hours: 24));

  String syncStatus = BridgyBackend.modeLabel;
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
    final client = BridgyBackend.client;
    if (client == null) return;
    try {
      final rows = await client
          .from('wallets')
          .select()
          .order('id')
          .limit(1);
      if (rows.isEmpty) {
        syncStatus = 'no wallet row';
        notifyListeners();
        return;
      }
      final row = rows.first;
      _rowId = row['id'];
      perTxLimitInr = _toDouble(row['per_tx_limit_inr'], perTxLimitInr);
      dailyLimitInr = _toDouble(row['daily_limit_inr'], dailyLimitInr);
      spentTodayInr = _toDouble(row['spent_today_inr'], spentTodayInr);
      final expiry = DateTime.tryParse('${row['policy_expiry']}');
      if (expiry != null) expiresAt = expiry.toLocal();
      syncStatus = 'synced';
    } on Exception catch (e) {
      syncStatus = 'load failed: $e';
    }
    notifyListeners();
  }

  Future<void> save() async {
    final client = BridgyBackend.client;
    if (client == null) return;
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
            .insert({
              'smart_wallet_address': 'pending',
              'agent_session_key': 'pending',
              ...payload,
            })
            .select('id')
            .single();
        _rowId = inserted['id'];
      }
      syncStatus = 'saved';
    } on Exception catch (e) {
      syncStatus = 'save failed: $e';
    }
    notifyListeners();
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
