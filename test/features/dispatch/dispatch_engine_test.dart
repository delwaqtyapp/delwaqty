import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/dispatch/domain/dispatch_engine.dart';

DriverCandidate driver({
  required String id,
  double distanceKm = 1,
  double etaToPickupMinutes = 1,
  int activeOrders = 0,
  bool isAvailable = true,
  bool vehicleSuitable = true,
  bool serviceCategoryMatch = true,
  bool deliveryZoneMatch = true,
  double routeCompatibility = 1,
  double batchingCompatibility = 1,
}) =>
    DriverCandidate(
      id: id,
      currentLatitude: 0,
      currentLongitude: 0,
      distanceKm: distanceKm,
      etaToPickupMinutes: etaToPickupMinutes,
      etaToDestinationMinutes: etaToPickupMinutes + 5,
      activeOrders: activeOrders,
      isAvailable: isAvailable,
      status: 'online',
      vehicleSuitable: vehicleSuitable,
      serviceCategoryMatch: serviceCategoryMatch,
      deliveryZoneMatch: deliveryZoneMatch,
      routeCompatibility: routeCompatibility,
      batchingCompatibility: batchingCompatibility,
    );

OrderDispatchContext order() => const OrderDispatchContext(
      pickupLatitude: 0,
      pickupLongitude: 0,
      destinationLatitude: 1,
      destinationLongitude: 1,
      priority: 1,
      ageMinutes: 0,
      slaDeadlineMinutes: 30,
      serviceCategory: 'food',
      deliveryZone: 'cairo',
    );

void main() {
  group('NearestDriverStrategy', () {
    test('ranks by ascending distance', () {
      final candidates = [
        driver(id: 'far', distanceKm: 10),
        driver(id: 'near', distanceKm: 2),
        driver(id: 'mid', distanceKm: 5),
      ];
      final ranked = NearestDriverStrategy().rank(
        order: order(),
        candidates: candidates,
      );
      expect(ranked.map((e) => e.candidate.id).toList(),
          ['near', 'mid', 'far']);
    });

    test('excludes offline drivers', () {
      final candidates = [
        driver(id: 'online', distanceKm: 2),
        driver(id: 'offline', distanceKm: 1, isAvailable: false),
      ];
      final ranked = NearestDriverStrategy().rank(
        order: order(),
        candidates: candidates,
      );
      expect(ranked.map((e) => e.candidate.id).toList(), ['online']);
    });
  });

  group('SmartScoreStrategy', () {
    test('ranks by combined score, not just distance', () {
      // A is closer but overloaded + wrong zone; B is farther but free + matched.
      final a = driver(
        id: 'A',
        distanceKm: 1,
        activeOrders: 5,
        deliveryZoneMatch: false,
      );
      final b = driver(
        id: 'B',
        distanceKm: 4,
        activeOrders: 0,
        deliveryZoneMatch: true,
      );
      final ranked = SmartScoreStrategy().rank(
        order: order(),
        candidates: [a, b],
      );
      expect(ranked.first.candidate.id, 'B');
    });

    test('score is deterministic for identical inputs', () {
      final a = driver(id: 'A', distanceKm: 3, activeOrders: 1);
      final b = driver(id: 'A', distanceKm: 3, activeOrders: 1);
      final s1 = SmartScoreStrategy().rank(order: order(), candidates: [a]);
      final s2 = SmartScoreStrategy().rank(order: order(), candidates: [b]);
      expect(s1.first.score, s2.first.score);
    });
  });

  group('HybridStrategy', () {
    test('proposes smart order but requires approval and is not automatic', () {
      final candidates = [
        driver(id: 'A', distanceKm: 10, activeOrders: 4),
        driver(id: 'B', distanceKm: 2, activeOrders: 0),
      ];
      final strategy = HybridStrategy();
      final ranked = strategy.rank(order: order(), candidates: candidates);
      expect(strategy.automatic, isFalse);
      expect(strategy.requiresApproval, isTrue);
      expect(ranked.first.candidate.id, 'B');
    });
  });

  group('ManualStrategy', () {
    test('returns available drivers unsorted, not automatic', () {
      final candidates = [
        driver(id: 'z', distanceKm: 1),
        driver(id: 'a', distanceKm: 50),
      ];
      final strategy = ManualStrategy();
      final ranked = strategy.rank(order: order(), candidates: candidates);
      expect(strategy.automatic, isFalse);
      expect(ranked.map((e) => e.candidate.id).toList(), ['a', 'z']);
    });
  });

  group('evaluateDispatch / failure', () {
    test('empty candidate list -> empty ranking + noAvailableDriver', () {
      final ranked = evaluateDispatch(
        strategy: SmartScoreStrategy(),
        order: order(),
        candidates: const [],
      );
      expect(ranked, isEmpty);
      expect(classifyDispatchFailure(const []),
          DispatchFailureReason.noAvailableDriver);
    });

    test('available but unsuitable -> noSuitableDriver', () {
      final candidates = [
        driver(id: 'x', vehicleSuitable: false, serviceCategoryMatch: false),
      ];
      expect(classifyDispatchFailure(candidates),
          DispatchFailureReason.noSuitableDriver);
    });
  });

  group('Atomic assignment (concurrency guard)', () {
    test('exactly one of two concurrent assignments succeeds', () {
      final assignment = DispatchAssignment('ORD-1', kPendingDispatch);

      // Simulate two dispatchers reading PENDING and attempting assign.
      final first = assignment.assign('DRIVER-A');
      final second = assignment.assign('DRIVER-B');

      expect(first, DispatchAssignmentResult.assigned);
      expect(second, DispatchAssignmentResult.rejectedStale);
      expect(assignment.assignedDriverId, 'DRIVER-A');
      expect(assignment.status, kAssigned);
    });

    test('assignment against non-pending order is rejected as stale', () {
      final assignment = DispatchAssignment('ORD-2', kAssigned)
        ..assignedDriverId = 'DRIVER-X';
      final result = assignment.assign('DRIVER-Y');
      expect(result, DispatchAssignmentResult.rejectedStale);
      expect(assignment.assignedDriverId, 'DRIVER-X');
    });
  });
}
