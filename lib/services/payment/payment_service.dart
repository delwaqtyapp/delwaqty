/// Available payment method types.
enum PaymentMethodType {
  /// Credit or debit card.
  card,

  /// Digital wallet (Apple Pay, Google Pay, etc.).
  wallet,

  /// Cash on delivery.
  cashOnDelivery,

  /// Bank transfer.
  bankTransfer,
}

/// Status of a payment transaction.
enum PaymentStatus {
  /// Payment is pending confirmation.
  pending,

  /// Payment has been successfully processed.
  completed,

  /// Payment was declined or failed.
  failed,

  /// Payment has been fully refunded.
  refunded,

  /// Payment was partially refunded.
  partiallyRefunded,

  /// Payment was cancelled before processing.
  cancelled,
}

/// Represents a saved or available payment method.
class PaymentMethod {
  /// Creates a [PaymentMethod].
  const PaymentMethod({
    required this.id,
    required this.type,
    required this.displayName,
    this.lastFourDigits,
    this.expiryMonth,
    this.expiryYear,
    this.isDefault = false,
    this.brand,
  });

  /// Unique identifier for this payment method.
  final String id;

  /// Type of payment method.
  final PaymentMethodType type;

  /// Human-readable label (e.g. "Visa **** 4242").
  final String displayName;

  /// Last four digits of the card number, if applicable.
  final String? lastFourDigits;

  /// Card expiry month (1-12), if applicable.
  final int? expiryMonth;

  /// Card expiry year, if applicable.
  final int? expiryYear;

  /// Whether this is the user's default payment method.
  final bool isDefault;

  /// Card brand (Visa, Mastercard, etc.), if applicable.
  final String? brand;
}

/// Result returned by a payment operation.
class PaymentResult {
  /// Creates a [PaymentResult].
  const PaymentResult({
    required this.success,
    required this.status,
    this.paymentId,
    this.errorMessage,
    this.receiptUrl,
  });

  /// Whether the operation succeeded.
  final bool success;

  /// Current status of the payment.
  final PaymentStatus status;

  /// Unique identifier of the payment transaction.
  final String? paymentId;

  /// Human-readable error message if the operation failed.
  final String? errorMessage;

  /// URL to a payment receipt, if available.
  final String? receiptUrl;
}

/// Abstract interface for payment processing services.
///
/// Handles initialisation, payment method management, transaction creation,
/// processing, refunds, and card tokenisation.
abstract interface class PaymentService {
  /// Initialises the payment gateway SDK.
  Future<void> initialize();

  /// Returns the list of payment methods available to the current user.
  Future<List<PaymentMethod>> getPaymentMethods();

  /// Creates a payment intent/transaction for the given [amount] in the
  /// specified [currency] using the payment method identified by [methodId].
  Future<PaymentResult> createPayment({
    required double amount,
    required String currency,
    required String methodId,
  });

  /// Processes (confirms) a previously created payment identified by [paymentId].
  Future<PaymentResult> processPayment(String paymentId);

  /// Issues a full or partial refund for the payment identified by [paymentId].
  Future<PaymentResult> refundPayment(String paymentId, {double? amount});

  /// Retrieves the current status of the payment identified by [paymentId].
  Future<PaymentStatus> getPaymentStatus(String paymentId);

  /// Tokenises card details for secure storage without exposing raw numbers.
  ///
  /// Returns a token string that can be used in place of the card details.
  Future<String> tokenizeCard({
    required String cardNumber,
    required String expiry,
    required String cvv,
  });
}
