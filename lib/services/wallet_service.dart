import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend.dart';

/// Raised when the wallet API returns an error. The message is the exact text
/// from the backend, so callers show it without inventing a fallback.
class WalletApiException implements Exception {
  const WalletApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class WalletPaymentResult {
  const WalletPaymentResult({
    required this.message,
    this.txHash,
    this.type,
    this.balanceInr,
  });

  final String message;
  final String? txHash;
  final String? type;
  final double? balanceInr;
}

class WalletStatus {
  const WalletStatus({
    required this.balanceInr,
    required this.perTxLimitInr,
    required this.dailyLimitInr,
    required this.spentTodayInr,
    required this.policyExpiry,
    required this.smartAccountAddress,
    required this.isLive,
  });

  final double balanceInr;
  final double perTxLimitInr;
  final double dailyLimitInr;
  final double spentTodayInr;
  final DateTime policyExpiry;
  final String smartAccountAddress;
  final bool isLive;
}

class TopUpOrder {
  const TopUpOrder({
    required this.id,
    required this.amountInr,
    required this.status,
    this.checkoutUrl,
    this.balanceInr,
  });

  final String id;
  final double amountInr;
  final String status;
  final String? checkoutUrl;
  final double? balanceInr;

  bool get isPaid => status == 'PAID';
  bool get isFinished =>
      status == 'PAID' || status == 'FAILED' || status == 'EXPIRED';
}

class WalletService {
  /// Production backend. No localhost or machine-specific override exists.
  static const String defaultBaseUrl = 'https://bridgy-backend.vercel.app';

  static Future<Map<String, String>> _headers() async {
    final token = BridgyBackend.accessToken;
    if (token == null || token.isEmpty) {
      throw const WalletApiException(
        'Sign in required: no Supabase session.',
        statusCode: 401,
        code: 'UNAUTHORIZED',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Uri _uri(String path) => Uri.parse('$defaultBaseUrl$path');

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = await _headers();
    final response = switch (method) {
      'GET' =>
        await http
            .get(_uri(path), headers: headers)
            .timeout(const Duration(seconds: 15)),
      'POST' =>
        await http
            .post(_uri(path), headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 20)),
      _ => throw WalletApiException('Unsupported method $method'),
    };

    final decoded = _decodeObject(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WalletApiException(
        _errorMessage(decoded, response.statusCode),
        statusCode: response.statusCode,
        code: decoded['code'] as String?,
      );
    }
    return decoded;
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Reported below with the raw body attached.
    }
    throw WalletApiException(
      'Backend returned invalid JSON (HTTP ${response.statusCode}): '
      '${response.body}',
      statusCode: response.statusCode,
    );
  }

  static String _errorMessage(Map<String, dynamic> body, int statusCode) {
    final error = body['error'];
    final code = body['code'];
    if (error is String && error.isNotEmpty) {
      return code is String && code.isNotEmpty ? '$error ($code)' : error;
    }
    return 'Wallet API failed with HTTP $statusCode';
  }

  static Future<WalletStatus> getStatus() async {
    final body = await _request('GET', '/api/wallet/status');
    final policy = body['policy'];
    if (policy is! Map<String, dynamic>) {
      throw const WalletApiException('Backend returned no policy');
    }
    final validUntil = policy['validUntilTimestamp'];
    return WalletStatus(
      balanceInr: _number(body['balanceInr']),
      perTxLimitInr: _number(policy['perTxLimitInr']),
      dailyLimitInr: _number(policy['dailyLimitInr']),
      spentTodayInr: _number(policy['spentTodayInr']),
      policyExpiry: validUntil is num
          ? DateTime.fromMillisecondsSinceEpoch((validUntil * 1000).toInt())
          : DateTime.fromMillisecondsSinceEpoch(0),
      smartAccountAddress: '${body['smartAccountAddress'] ?? ''}',
      isLive: body['isLive'] == true,
    );
  }

  static Future<double> getBalance() async {
    final body = await _request('GET', '/api/wallet/balance');
    return _number(body['balanceInr']);
  }

  static Future<List<Map<String, dynamic>>> getTransactions({
    int limit = 20,
  }) async {
    final body = await _request('GET', '/api/wallet/transactions?limit=$limit');
    final rows = body['transactions'];
    if (rows is! List) {
      throw const WalletApiException('Backend returned no transactions list');
    }
    return rows.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static Future<TopUpOrder> createTopUp(double amountInr) async {
    final body = await _request(
      'POST',
      '/api/wallet/topup',
      body: {'amountInr': amountInr},
    );
    return _order(body);
  }

  static Future<TopUpOrder> getTopUp(String id) async {
    final body = await _request('GET', '/api/wallet/topup/$id');
    return _order(body);
  }

  static TopUpOrder _order(Map<String, dynamic> body) {
    final id = body['id'];
    if (id is! String) {
      throw const WalletApiException('Backend returned no top-up id');
    }
    return TopUpOrder(
      id: id,
      amountInr: _number(body['amountInr']),
      status: '${body['status'] ?? 'PENDING'}',
      checkoutUrl: body['checkoutUrl'] as String?,
      balanceInr: body['balanceInr'] == null
          ? null
          : _number(body['balanceInr']),
    );
  }

  static Future<WalletPaymentResult> payWithAgent({
    required double amountInr,
    required String merchantName,
    required String merchantVpa,
  }) async {
    final body = await _request(
      'POST',
      '/api/wallet/pay-agent',
      body: {
        'amountInr': amountInr,
        'merchantName': merchantName,
        'merchantVpa': merchantVpa,
      },
    );
    final tx = body['transaction'];
    final txMap = tx is Map<String, dynamic> ? tx : const <String, dynamic>{};
    return WalletPaymentResult(
      message: '${body['message'] ?? 'Paid'}',
      txHash: txMap['txHash'] as String?,
      type: txMap['type'] as String? ?? 'AGENT_PAID',
      balanceInr: txMap['balanceInr'] == null
          ? null
          : _number(txMap['balanceInr']),
    );
  }

  static Future<WalletPaymentResult> payWithOwner({
    required double amountInr,
    required String merchantName,
    required String merchantVpa,
    bool biometricApproved = true,
  }) async {
    final body = await _request(
      'POST',
      '/api/wallet/pay-owner',
      body: {
        'amountInr': amountInr,
        'merchantName': merchantName,
        'merchantVpa': merchantVpa,
        'biometricApproved': biometricApproved,
      },
    );
    final tx = body['transaction'];
    final txMap = tx is Map<String, dynamic> ? tx : const <String, dynamic>{};
    return WalletPaymentResult(
      message: '${body['message'] ?? 'Paid'}',
      txHash: txMap['txHash'] as String?,
      type: txMap['type'] as String? ?? 'OWNER_PAID',
      balanceInr: txMap['balanceInr'] == null
          ? null
          : _number(txMap['balanceInr']),
    );
  }

  static Future<WalletStatus> updatePolicy({
    required double perTxLimitInr,
    required double dailyLimitInr,
  }) async {
    await _request(
      'POST',
      '/api/wallet/policy',
      body: {'perTxLimitInr': perTxLimitInr, 'dailyLimitInr': dailyLimitInr},
    );
    return getStatus();
  }

  static Future<void> renewSession() async {
    await _request('POST', '/api/wallet/renew-session');
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    throw WalletApiException('Backend returned a non-numeric value: $value');
  }
}
