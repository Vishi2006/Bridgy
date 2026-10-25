import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WalletPaymentResult {
  final bool success;
  final String message;
  final String? txHash;
  final String? type;
  final bool requiresOwnerApproval;
  final String? error;

  const WalletPaymentResult({
    required this.success,
    required this.message,
    this.txHash,
    this.type,
    this.requiresOwnerApproval = false,
    this.error,
  });
}

/// Raised when the wallet API returns an error. The message is the exact text
/// from the backend, so callers can show it without inventing a fallback.
class WalletApiException implements Exception {
  const WalletApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class TopUpResult {
  const TopUpResult({
    required this.amountInr,
    required this.balanceInr,
    required this.transactionId,
  });

  final double amountInr;
  final double balanceInr;
  final String transactionId;
}

class WalletService {
  /// Production backend. No localhost or student-machine override ships here.
  static const String defaultBaseUrl = 'https://bridgy-backend.vercel.app';

  static Future<String> getBaseUrl() async => defaultBaseUrl;

  /// Live balance from the Supabase ledger through the backend.
  ///
  /// Throws [WalletApiException] with the backend message on any failure; it
  /// never returns a cached or local number.
  static Future<double> getBalance() async {
    final base = await getBaseUrl();
    final res = await http
        .get(Uri.parse('$base/api/wallet/balance'))
        .timeout(const Duration(seconds: 10));

    final body = _decodeObject(res);
    if (res.statusCode != 200) {
      throw WalletApiException(_errorMessage(body, res.statusCode));
    }

    final balance = body['balanceInr'];
    if (balance is! num) {
      throw WalletApiException(
        'Backend returned no balanceInr (HTTP ${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    return balance.toDouble();
  }

  /// Credits the wallet. The backend writes balance, top-up row, and ledger row
  /// in one transaction and returns the authoritative new balance.
  static Future<TopUpResult> topUp(double amountInr) async {
    final base = await getBaseUrl();
    final res = await http
        .post(
          Uri.parse('$base/api/wallet/topup'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'amountInr': amountInr}),
        )
        .timeout(const Duration(seconds: 15));

    final body = _decodeObject(res);
    if (res.statusCode != 201) {
      throw WalletApiException(_errorMessage(body, res.statusCode));
    }

    final balance = body['balanceInr'];
    final transactionId = body['transactionId'];
    if (balance is! num || transactionId is! String) {
      throw WalletApiException(
        'Backend returned an incomplete top-up (HTTP ${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    return TopUpResult(
      amountInr: (body['amountInr'] as num?)?.toDouble() ?? amountInr,
      balanceInr: balance.toDouble(),
      transactionId: transactionId,
    );
  }

  static Map<String, dynamic> _decodeObject(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Reported below with the raw body attached.
    }
    throw WalletApiException(
      'Backend returned invalid JSON (HTTP ${res.statusCode}): ${res.body}',
      statusCode: res.statusCode,
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

  static Future<Map<String, dynamic>?> getStatus() async {
    try {
      final base = await getBaseUrl();
      final res = await http
          .get(Uri.parse('$base/api/wallet/status'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[WalletService] getStatus error: $e');
    }
    return null;
  }

  static Future<WalletPaymentResult> payWithAgent({
    required double amountInr,
    required String merchantName,
    required String merchantVpa,
    String? targetAddress,
  }) async {
    try {
      final base = await getBaseUrl();
      final res = await http
          .post(
            Uri.parse('$base/api/wallet/pay-agent'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'amountInr': amountInr,
              'merchantName': merchantName,
              'merchantVpa': merchantVpa,
              if (targetAddress != null) 'targetAddress': targetAddress,
            }),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final tx = data['transaction'] as Map<String, dynamic>?;
        return WalletPaymentResult(
          success: true,
          message: data['message'] ?? 'Paid via AI Agent Session Key',
          txHash: tx?['txHash'] as String?,
          type: (tx?['type'] as String?) ?? 'AGENT_PAID',
        );
      } else {
        return WalletPaymentResult(
          success: false,
          message: data['error'] ?? 'Agent payment declined',
          error: data['error'] as String?,
          requiresOwnerApproval: data['requires_owner_approval'] == true,
        );
      }
    } catch (e) {
      debugPrint('[WalletService] payWithAgent error: $e');
      return WalletPaymentResult(
        success: false,
        message: 'Network error: $e',
        error: e.toString(),
      );
    }
  }

  static Future<WalletPaymentResult> payWithOwner({
    required double amountInr,
    required String merchantName,
    required String merchantVpa,
    String? targetAddress,
    bool biometricApproved = true,
  }) async {
    try {
      final base = await getBaseUrl();
      final res = await http
          .post(
            Uri.parse('$base/api/wallet/pay-owner'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'amountInr': amountInr,
              'merchantName': merchantName,
              'merchantVpa': merchantVpa,
              'biometricApproved': biometricApproved,
              if (targetAddress != null) 'targetAddress': targetAddress,
            }),
          )
          .timeout(const Duration(seconds: 6));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && data['success'] == true) {
        final tx = data['transaction'] as Map<String, dynamic>?;
        return WalletPaymentResult(
          success: true,
          message: data['message'] ?? 'Paid with Owner Master Key',
          txHash: tx?['txHash'] as String?,
          type: (tx?['type'] as String?) ?? 'OWNER_PAID',
        );
      } else {
        return WalletPaymentResult(
          success: false,
          message: data['error'] ?? 'Owner payment failed',
          error: data['error'] as String?,
        );
      }
    } catch (e) {
      debugPrint('[WalletService] payWithOwner error: $e');
      return WalletPaymentResult(
        success: false,
        message: 'Network error: $e',
        error: e.toString(),
      );
    }
  }

  static Future<bool> renewSession() async {
    try {
      final base = await getBaseUrl();
      final res = await http
          .post(Uri.parse('$base/api/wallet/renew-session'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updatePolicy({
    required double perTxLimitInr,
    required double dailyLimitInr,
  }) async {
    try {
      final base = await getBaseUrl();
      final res = await http
          .post(
            Uri.parse('$base/api/wallet/policy'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'perTxLimitInr': perTxLimitInr,
              'dailyLimitInr': dailyLimitInr,
            }),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
