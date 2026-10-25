import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  double _balance = 2486.12;
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

  String get balanceText {
    final parts = _balance.toStringAsFixed(2).split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '\$ $whole.${parts[1]}';
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _balance = prefs.getDouble('unipay_balance') ?? _balance;
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
      WalletTx(
        title: title,
        subtitle: subtitle,
        amount: amount,
        kind: kind,
      ),
    );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('unipay_balance', _balance);
  }

  Future<void> reset() async {
    _balance = 2486.12;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('unipay_balance', _balance);
  }
}
