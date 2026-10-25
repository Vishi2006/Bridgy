import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/wallet_service.dart';

class WalletTx {
  const WalletTx({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final double amount;
  final String kind;
}

class WalletStore extends ChangeNotifier {
  WalletStore._();

  static final WalletStore instance = WalletStore._();

  double _balance = 0;
  bool _loaded = false;
  String? _error;
  final List<WalletTx> _transactions = [
    const WalletTx(
      title: 'Dribbble',
      subtitle: '12 February 2023',
      amount: -15.00,
      kind: 'dribbble',
    ),
    const WalletTx(
      title: 'Mailchimp',
      subtitle: '02 March 2023',
      amount: -350.00,
      kind: 'mailchimp',
    ),
  ];

  double get balance => _balance;
  List<WalletTx> get transactions => List.unmodifiable(_transactions);

  /// False until the first successful backend read.
  bool get loaded => _loaded;

  /// Exact backend error, shown in the UI. Null when the last read succeeded.
  String? get error => _error;

  String get _wholePart {
    final whole = _balance.toStringAsFixed(2).split('.')[0];
    return whole.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
  }

  String get balanceWhole => _loaded ? '₹$_wholePart' : '₹—';

  String get balanceFraction =>
      _loaded ? '.${_balance.toStringAsFixed(2).split('.')[1]}' : '';

  String get balanceText => '$balanceWhole$balanceFraction';

  /// Reads the authoritative balance from the backend ledger.
  ///
  /// The error is stored verbatim so the home card can display it. There is no
  /// local balance to fall back to.
  Future<void> refresh() async {
    try {
      _balance = await WalletService.getBalance();
      _loaded = true;
      _error = null;
    } on Exception catch (error) {
      _error = error.toString();
    }
    notifyListeners();
  }

  Future<void> load() => refresh();

  /// Applies the balance returned by a confirmed top-up, plus its ledger row.
  Future<void> applyTopUp({
    required double amountInr,
    required double balanceInr,
  }) async {
    _balance = balanceInr;
    _loaded = true;
    _error = null;
    _transactions.insert(
      0,
      WalletTx(
        title: 'Wallet top-up',
        subtitle: 'Just now',
        amount: amountInr,
        kind: 'topup',
      ),
    );
    notifyListeners();
  }

  Future<void> apply({
    required double amount,
    required String title,
    required String subtitle,
    required String kind,
  }) async {
    final next = _balance + amount;
    if (next < 0) return;
    _balance = next;
    _transactions.insert(
      0,
      WalletTx(title: title, subtitle: subtitle, amount: amount, kind: kind),
    );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('unipay_balance', _balance);
  }

  Future<void> reset() async {
    _balance = 0;
    _loaded = false;
    _error = null;
    _transactions
      ..clear()
      ..addAll(const [
        WalletTx(
          title: 'Dribbble',
          subtitle: '12 February 2023',
          amount: -15.00,
          kind: 'dribbble',
        ),
        WalletTx(
          title: 'Mailchimp',
          subtitle: '02 March 2023',
          amount: -350.00,
          kind: 'mailchimp',
        ),
      ]);
    notifyListeners();
  }
}
