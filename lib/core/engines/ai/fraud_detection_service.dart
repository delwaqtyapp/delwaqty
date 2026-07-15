/// A transaction to be analyzed for fraud signals.
class Transaction {
  /// Creates a [Transaction] instance.
  const Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.type,
    required this.timestamp,
    this.merchantId,
    this.location,
    this.paymentMethod,
    this.metadata = const {},
  });

  /// Unique transaction identifier.
  final String id;

  /// Identifier of the user performing the transaction.
  final String userId;

  /// Transaction amount.
  final double amount;

  /// Currency code (ISO 4217).
  final String currency;

  /// Transaction type (e.g., "purchase", "refund", "transfer").
  final String type;

  /// Timestamp of the transaction.
  final DateTime timestamp;

  /// Identifier of the merchant involved, if applicable.
  final String? merchantId;

  /// Location where the transaction occurred.
  final TransactionLocation? location;

  /// Payment method used.
  final String? paymentMethod;

  /// Additional transaction metadata.
  final Map<String, dynamic> metadata;
}

/// Location data for a transaction.
class TransactionLocation {
  /// Creates a [TransactionLocation] instance.
  const TransactionLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  /// Latitude coordinate.
  final double latitude;

  /// Longitude coordinate.
  final double longitude;

  /// Human-readable address, if available.
  final String? address;
}

/// Fraud analysis result for a transaction.
class FraudScore {
  /// Creates a [FraudScore] instance.
  const FraudScore({
    required this.transactionId,
    required this.score,
    required this.riskLevel,
    this.flags = const [],
    this.explanation,
  });

  /// Identifier of the analyzed transaction.
  final String transactionId;

  /// Fraud probability score between 0.0 (safe) and 1.0 (highly suspicious).
  final double score;

  /// Assessed risk level.
  final RiskLevel riskLevel;

  /// List of triggered fraud flags.
  final List<String> flags;

  /// Human-readable explanation of the fraud assessment.
  final String? explanation;
}

/// Risk levels for user behavior or transactions.
enum RiskLevel {
  /// No detected risk.
  low,

  /// Minor suspicious indicators.
  medium,

  /// Significant fraud indicators present.
  high,

  /// Confirmed or near-certain fraud.
  critical,
}

/// User behavior event for risk analysis.
class UserBehaviorAction {
  /// Creates a [UserBehaviorAction] instance.
  const UserBehaviorAction({
    required this.action,
    required this.timestamp,
    this.targetId,
    this.metadata = const {},
  });

  /// The action performed (e.g., "login", "purchase", "password_change").
  final String action;

  /// When the action occurred.
  final DateTime timestamp;

  /// Identifier of the target entity, if applicable.
  final String? targetId;

  /// Additional metadata for the action.
  final Map<String, dynamic> metadata;
}

/// Fraud detection abstraction.
///
/// Analyzes transactions and user behavior for suspicious patterns,
/// manages risk scores, and enforces blocking rules.
abstract interface class FraudDetectionService {
  /// Analyzes a [transaction] and returns a fraud risk assessment.
  Future<FraudScore> analyzeTransaction(Transaction transaction);

  /// Analyzes a sequence of user [actions] for behavioral risk signals.
  Future<RiskLevel> analyzeUserBehavior(
    String userId,
    List<UserBehaviorAction> actions,
  );

  /// Flags a suspicious [activity] for manual review or automated action.
  Future<void> flagSuspiciousActivity(Map<String, dynamic> activity);

  /// Returns the cumulative risk score for the given [userId].
  ///
  /// A score closer to 1.0 indicates higher risk.
  Future<double> getRiskScore(String userId);

  /// Blocks the specified [userId] with the given [reason].
  Future<void> blockUser(String userId, String reason);

  /// Checks whether the given [userId] is currently blocked.
  Future<bool> isBlocked(String userId);
}
