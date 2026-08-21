import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:delwaqty/config/app_config.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final paymobServiceProvider = Provider<PaymobService>((ref) {
  return PaymobService(ref.watch(loggerProvider));
});

class PaymobService {
  PaymobService(this._logger);

  final AppLogger _logger;

  static const String _baseUrl = 'https://accept.paymobsolutions.com/api';

  Future<String?> authenticate() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/tokens'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': AppConfig.paymobApiKey}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'] as String?;
      }
      _logger.e('Paymob auth failed: ${response.statusCode}');
      return null;
    } catch (e) {
      _logger.e('Paymob auth error', e);
      return null;
    }
  }

  Future<int?> createOrder({
    required String authToken,
    required double amountCents,
    String? merchantOrderId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ecommerce/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'auth_token': authToken,
          'delivery_needed': false,
          'amount_cents': (amountCents * 100).toInt(),
          'currency': 'EGP',
          'merchant_order_id': merchantOrderId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'items': [],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] as int?;
      }
      _logger.e('Paymob order creation failed: ${response.statusCode}');
      return null;
    } catch (e) {
      _logger.e('Paymob order creation error', e);
      return null;
    }
  }

  Future<String?> getPaymentKey({
    required String authToken,
    required int orderId,
    required double amountCents,
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/acceptance/payment_keys'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'auth_token': authToken,
          'amount_cents': (amountCents * 100).toInt(),
          'expiration': 3600,
          'order_id': orderId,
          'billing_data': {
            'email': email,
            'first_name': 'Customer',
            'last_name': 'Delwaqty',
            'phone_number': '+201000000000',
          },
          'currency': 'EGP',
          'integration_id': AppConfig.paymobIntegrationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'] as String?;
      }
      _logger.e('Paymob payment key failed: ${response.statusCode}');
      return null;
    } catch (e) {
      _logger.e('Paymob payment key error', e);
      return null;
    }
  }

  String getPaymentUrl(String paymentKey) {
    const iframeId = AppConfig.paymobIframeId;
    return 'https://accept.paymobsolutions.com/api/acceptance/iframes/$iframeId?payment_token=$paymentKey';
  }

  bool verifyCallback(Map<String, String> params) {
    final success = params['success'] == 'true';
    final orderId = params['order'];
    _logger.i('Paymob callback: success=$success, order=$orderId');
    return success;
  }
}
