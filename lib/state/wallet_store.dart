import 'package:flutter/foundation.dart';

import '../services/wallet_service.dart';

class WalletTx {
  const WalletTx({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.kind,
  });

  final String id;
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
  double? _onchainEth;
  String? _onchainAddress;
  String? _onchainError;
  List<WalletTx> _transactions = const [];

  double get balance => _balance;
  List<WalletTx> get transactions => List.unmodifiable(_transactions);

  /// False until the first successful backend read.
  bool get loaded => _loaded;

  /// Exact backend error, shown in the UI. Null when the last read succeeded.
  String? get error => _error;

  /// Base Sepolia ETH balance at the user's smart account.
  double? get onchainEth => _onchainEth;

  String? get onchainAddress => _onchainAddress;

  /// Non-null when the chain read or demo-rate credit failed.
  String? get onchainError => _onchainError;

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

  /// Reads the authoritative balance and ledger rows from the backend.
  ///
  /// The error is stored verbatim so the home card can display it. There is no
  /// local balance or seeded transaction list to fall back to.
  Future<void> refresh() async {
    try {
      final snapshot = await WalletService.getBalance();
      final rows = await WalletService.getTransactions();
      _balance = snapshot.balanceInr;
      _onchainEth = snapshot.onchainEth;
      _onchainAddress = snapshot.onchainAddress;
      _onchainError = snapshot.onchainError;
      _loaded = true;
      _error = null;
      _transactions = rows.map(_mapTransaction).toList(growable: false);
    } on Exception catch (error) {
      _error = error.toString();
    }
    notifyListeners();
  }

  /// Applies the balance returned by a confirmed top-up, then reloads history.
  Future<void> applyTopUp({
    required double amountInr,
    required double balanceInr,
  }) async {
    _balance = balanceInr;
    _loaded = true;
    _error = null;
    notifyListeners();
    await refresh();
  }

  /// Clears all user data on sign-out.
  void clear() {
    _balance = 0;
    _loaded = false;
    _error = null;
    _onchainEth = null;
    _onchainAddress = null;
    _onchainError = null;
    _transactions = const [];
    notifyListeners();
  }

  WalletTx _mapTransaction(Map<String, dynamic> row) {
    final status = '${row['status'] ?? ''}';
    final merchant = '${row['merchantName'] ?? 'Transaction'}';
    final amount = (row['amountInr'] as num?)?.toDouble() ?? 0;
    final createdAt = DateTime.tryParse('${row['createdAt'] ?? ''}');
    final credit = status == 'TOPUP' || status == 'CRYPTO_TOPUP';
    return WalletTx(
      id: '${row['id'] ?? ''}',
      title: merchant,
      subtitle: _formatDate(createdAt) ?? 'Just now',
      amount: credit ? amount : -amount,
      kind: status.toLowerCase(),
    );
  }

  String? _formatDate(DateTime? value) {
    if (value == null) return null;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final local = value.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}
