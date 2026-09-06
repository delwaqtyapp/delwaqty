/// Deterministic, server-authoritative-friendly delivery dispatch model.
///
/// This module encodes the *decision logic* of the Smart Delivery Dispatch
/// Engine. It is intentionally pure Dart (no I/O) so the scoring,
/// ranking and atomic-assignment semantics can be unit-tested without a
/// database. The actual DB boundary (FOR UPDATE guard, RLS, SECURITY DEFINER
/// RPCs) is implemented in SQL migrations; this layer mirrors that contract.
library;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class OrderDispatchContext {

  const OrderDispatchContext({
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.priority,
    required this.ageMinutes,
    required this.slaDeadlineMinutes,
    required this.serviceCategory,
    required this.deliveryZone,
  });
  final double pickupLatitude;
  final double pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  /// Higher = more urgent (1 = normal, 5 = critical).
  final int priority;

  /// Minutes since the order entered PENDING_DISPATCH.
  final double ageMinutes;

  /// SLA deadline in minutes from creation. <=0 means "no hard deadline".
  final double slaDeadlineMinutes;

  final String serviceCategory;
  final String deliveryZone;
}

class DriverCandidate {

  const DriverCandidate({
    required this.id,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.distanceKm,
    required this.etaToPickupMinutes,
    required this.etaToDestinationMinutes,
    required this.activeOrders,
    required this.isAvailable,
    required this.status,
    required this.vehicleSuitable,
    required this.serviceCategoryMatch,
    required this.deliveryZoneMatch,
    required this.routeCompatibility,
    required this.batchingCompatibility,
  });
  final String id;
  final double currentLatitude;
  final double currentLongitude;

  /// Precomputed great-circle distance to the pickup point (km).
  final double distanceKm;

  final double etaToPickupMinutes;
  final double etaToDestinationMinutes;
  final int activeOrders;
  final bool isAvailable;

  /// Logical driver status, e.g. 'online'.
  final String status;

  final bool vehicleSuitable;
  final bool serviceCategoryMatch;
  final bool deliveryZoneMatch;

  /// 0..1 directional alignment toward pickup.
  final double routeCompatibility;

  /// 0..1 ability to batch with current active orders.
  final double batchingCompatibility;
}

/// Documented, configurable scoring weights.
///
/// Weights are normalized by [total]; the smart score is a convex
/// combination so the relative importance is preserved even if a caller
/// supplies unnormalized values. Defaults reflect a balanced policy:
/// proximity/ETA dominate, workload and SLA matter, zone and compatibility
/// are tie-breakers. Change centrally — never hardcode ad-hoc weights in UI.
class DispatchWeights {

  const DispatchWeights({
    this.distance = 0.30,
    this.eta = 0.25,
    this.workload = 0.15,
    this.sla = 0.15,
    this.zone = 0.10,
    this.compatibility = 0.05,
  });
  final double distance;
  final double eta;
  final double workload;
  final double sla;
  final double zone;
  final double compatibility;

  double get total => distance + eta + workload + sla + zone + compatibility;
}

class ScoredCandidate {

  const ScoredCandidate(this.candidate, this.score);
  final DriverCandidate candidate;
  final double score;
}

// ---------------------------------------------------------------------------
// Strategies
// ---------------------------------------------------------------------------

abstract class DispatchStrategy {
  String get name;

  /// When true the system may auto-assign without human approval.
  bool get automatic;

  /// When true the top proposal still requires an authorized ops admin
  /// to confirm (Hybrid mode).
  bool get requiresApproval => false;

  List<ScoredCandidate> rank({
    required OrderDispatchContext order,
    required List<DriverCandidate> candidates,
    DispatchWeights weights = const DispatchWeights(),
  });
}

/// Pure nearest-driver assignment (legacy-compatible fallback).
class NearestDriverStrategy extends DispatchStrategy {
  @override
  String get name => 'nearest';

  @override
  bool get automatic => true;

  @override
  List<ScoredCandidate> rank({
    required OrderDispatchContext order,
    required List<DriverCandidate> candidates,
    DispatchWeights weights = const DispatchWeights(),
  }) {
    final list = candidates.where(_available).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return [for (final c in list) ScoredCandidate(c, 1 / (1 + c.distanceKm))];
  }
}

/// Weighted, multi-factor candidate scoring (default smart dispatch).
class SmartScoreStrategy extends DispatchStrategy {
  @override
  String get name => 'smart';

  @override
  bool get automatic => true;

  @override
  List<ScoredCandidate> rank({
    required OrderDispatchContext order,
    required List<DriverCandidate> candidates,
    DispatchWeights weights = const DispatchWeights(),
  }) {
    final norm = weights.total <= 0 ? 1.0 : weights.total;
    final scored = candidates.where(_available).map((c) {
      return ScoredCandidate(c, _smartScore(c, order, weights) / norm);
    }).toList();
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  double _smartScore(
    DriverCandidate c,
    OrderDispatchContext o,
    DispatchWeights w,
  ) {
    final distanceScore = 1 / (1 + c.distanceKm);
    final etaScore = 1 / (1 + c.etaToPickupMinutes);
    final workloadScore = 1 / (1 + c.activeOrders);
    final slaUrgency = o.slaDeadlineMinutes <= 0
        ? 1.0
        : (o.ageMinutes / o.slaDeadlineMinutes).clamp(0.0, 1.0);
    final zoneScore = c.deliveryZoneMatch ? 1.0 : 0.0;
    final compatScore = ((c.vehicleSuitable ? 1.0 : 0.0) * 0.4 +
            (c.serviceCategoryMatch ? 1.0 : 0.0) * 0.4 +
            c.routeCompatibility * 0.1 +
            c.batchingCompatibility * 0.1)
        .clamp(0.0, 1.0);
    return w.distance * distanceScore +
        w.eta * etaScore +
        w.workload * workloadScore +
        w.sla * slaUrgency +
        w.zone * zoneScore +
        w.compatibility * compatScore;
  }
}

/// System proposes the best driver (smart score); an authorized ops admin
/// must approve or override before assignment.
class HybridStrategy extends DispatchStrategy {
  @override
  String get name => 'hybrid';

  @override
  bool get automatic => false;

  @override
  bool get requiresApproval => true;

  @override
  List<ScoredCandidate> rank({
    required OrderDispatchContext order,
    required List<DriverCandidate> candidates,
    DispatchWeights weights = const DispatchWeights(),
  }) =>
      SmartScoreStrategy().rank(
        order: order,
        candidates: candidates,
        weights: weights,
      );
}

/// No automatic ranking; authorized admins pick freely from available
/// drivers. Orders stay in PENDING_DISPATCH.
class ManualStrategy extends DispatchStrategy {
  @override
  String get name => 'manual';

  @override
  bool get automatic => false;

  @override
  List<ScoredCandidate> rank({
    required OrderDispatchContext order,
    required List<DriverCandidate> candidates,
    DispatchWeights weights = const DispatchWeights(),
  }) {
    final list = candidates.where(_available).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return [for (final c in list) ScoredCandidate(c, 0)];
  }
}

bool _available(DriverCandidate c) => c.isAvailable && c.status == 'online';

/// Reason an order remains unassigned.
enum DispatchFailureReason { none, noAvailableDriver, noSuitableDriver }

/// Evaluate candidates with the given strategy.
///
/// Returns an empty list when no assignable candidate exists; the caller is
/// responsible for keeping the order in PENDING_DISPATCH with the right
/// [DispatchFailureReason] (e.g. NO_AVAILABLE_DRIVER). This models the
/// "do not silently fail" requirement.
List<ScoredCandidate> evaluateDispatch({
  required DispatchStrategy strategy,
  required OrderDispatchContext order,
  required List<DriverCandidate> candidates,
  DispatchWeights weights = const DispatchWeights(),
}) {
  return strategy.rank(order: order, candidates: candidates, weights: weights);
}

DispatchFailureReason classifyDispatchFailure(
  List<DriverCandidate> candidates,
) {
  if (candidates.isEmpty) return DispatchFailureReason.noAvailableDriver;
  final available = candidates.where(_available).toList();
  if (available.isEmpty) return DispatchFailureReason.noAvailableDriver;
  final suitable = available
      .where((c) => c.vehicleSuitable && c.serviceCategoryMatch)
      .toList();
  if (suitable.isEmpty) return DispatchFailureReason.noSuitableDriver;
  return DispatchFailureReason.none;
}

// ---------------------------------------------------------------------------
// Atomic assignment (mirrors SQL FOR UPDATE / status guard)
// ---------------------------------------------------------------------------

/// Lifecycle states for an assignable order.
const String kPendingDispatch = 'PENDING_DISPATCH';
const String kAssigned = 'ASSIGNED';

enum DispatchAssignmentResult { assigned, rejectedStale, noCandidate }

/// Pure model of an order's assignment state. The [assign] transition
/// enforces the atomic PENDING_DISPATCH -> ASSIGNED guard: any attempt
/// against a non-PENDING order is rejected as stale, guaranteeing exactly
/// one successful assignment even under concurrent callers.
class DispatchAssignment {

  DispatchAssignment(this.orderId, this.status);
  final String orderId;
  String? assignedDriverId;
  String status;

  DispatchAssignmentResult assign(String driverId) {
    if (status != kPendingDispatch) {
      return DispatchAssignmentResult.rejectedStale;
    }
    if (assignedDriverId != null) {
      return DispatchAssignmentResult.rejectedStale;
    }
    assignedDriverId = driverId;
    status = kAssigned;
    return DispatchAssignmentResult.assigned;
  }
}
