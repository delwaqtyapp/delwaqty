import 'package:delwaqty/services/payment/payment_service.dart';

/// Mock implementation of [PaymentService] for development.
///
/// Returns placeholder payment data and always succeeds with a fake
/// payment ID. Suitable for local development and UI testing only.
class PaymentServiceImpl implements PaymentService {
  static int _counter = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PaymentMethod>> getPaymentMethods() async {
    return const [
      PaymentMethod(
        id: 'mock-card-1',
        type: PaymentMethodType.card,
        displayName: 'Visa **** 4242',
        lastFourDigits: '4242',
        expiryMonth: 12,
        expiryYear: 2027,
        isDefault: true,
        brand: 'Visa',
      ),
      PaymentMethod(
        id: 'mock-wallet-1',
        type: PaymentMethodType.wallet,
        displayName: 'Apple Pay',
        brand: 'Apple Pay',
      ),
      PaymentMethod(
        id: 'mock-cod-1',
        type: PaymentMethodType.cashOnDelivery,
        displayName: 'Cash on Delivery',
      ),
    ];
  }

  @override
  Future<PaymentResult> createPayment({
    required double amount,
    required String currency,
    required String methodId,
  }) async {
    _counter++;
    return PaymentResult(
      success: true,
      status: PaymentStatus.pending,
      paymentId: 'mock-payment-$_counter',
    );
  }

  @override
  Future<PaymentResult> processPayment(String paymentId) async {
    return PaymentResult(
      success: true,
      status: PaymentStatus.completed,
      paymentId: paymentId,
      receiptUrl: 'https://example.com/receipt/$paymentId',
    );
  }

  @override
  Future<PaymentResult> refundPayment(
    String paymentId, {
    double? amount,
  }) async {
    return PaymentResult(
      success: true,
      status: PaymentStatus.refunded,
      paymentId: paymentId,
    );
  }

  @override
  Future<PaymentStatus> getPaymentStatus(String paymentId) async {
    return PaymentStatus.completed;
  }

  @override
  Future<String> tokenizeCard({
    required String cardNumber,
    required String expiry,
    required String cvv,
  }) async {
    return 'mock-token-${cardNumber.substring(cardNumber.length - 4)}';
  }
}
