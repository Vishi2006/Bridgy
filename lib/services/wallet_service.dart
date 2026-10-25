import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

class WalletService {
  static const String defaultBaseUrl = 'https://bridgy-backend.vercel.app';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('backend_url') ?? defaultBaseUrl;
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
