import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/ride/domain/repositories/ride_repository.dart';
import 'package:delwaqty/features/ride/data/datasources/remote/supabase_ride_data_source.dart';
import 'package:delwaqty/features/ride/data/repositories/ride_repository_impl.dart';

final rideRepositoryImplProvider = Provider<RideRepositoryImpl>((ref) {
  return RideRepositoryImpl(ref.watch(supabaseRideDataSourceProvider));
});

final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => ref.watch(rideRepositoryImplProvider),
);

final activeRideProvider = FutureProvider<Ride?>((ref) async {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getActiveRide();
});

final rideHistoryProvider = FutureProvider<List<Ride>>((ref) async {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getRideHistory();
});

enum BookingStep { location, review, confirmed }

class RideBookingState {
  const RideBookingState({
    this.pickupAddress = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffAddress = '',
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.rideType = RideType.economy,
    this.estimatedFare,
    this.estimatedDistance,
    this.estimatedMinutes,
    this.step = BookingStep.location,
    this.isRequesting = false,
    this.error,
  });

  final String pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String dropoffAddress;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final RideType rideType;
  final double? estimatedFare;
  final double? estimatedDistance;
  final int? estimatedMinutes;
  final BookingStep step;
  final bool isRequesting;
  final String? error;

  bool get isReadyToBook =>
      pickupLatitude != null &&
      pickupLongitude != null &&
      dropoffLatitude != null &&
      dropoffLongitude != null &&
      pickupAddress.isNotEmpty &&
      dropoffAddress.isNotEmpty;

  RideBookingState copyWith({
    String? pickupAddress,
    double? pickupLatitude,
    double? pickupLongitude,
    bool clearPickupLat = false,
    bool clearPickupLng = false,
    String? dropoffAddress,
    double? dropoffLatitude,
    double? dropoffLongitude,
    bool clearDropoffLat = false,
    bool clearDropoffLng = false,
    RideType? rideType,
    double? estimatedFare,
    bool clearFare = false,
    double? estimatedDistance,
    bool clearDistance = false,
    int? estimatedMinutes,
    bool clearMinutes = false,
    BookingStep? step,
    bool? isRequesting,
    String? error,
    bool clearError = false,
  }) {
    return RideBookingState(
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLatitude: clearPickupLat ? null : (pickupLatitude ?? this.pickupLatitude),
      pickupLongitude: clearPickupLng ? null : (pickupLongitude ?? this.pickupLongitude),
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLatitude: clearDropoffLat ? null : (dropoffLatitude ?? this.dropoffLatitude),
      dropoffLongitude: clearDropoffLng ? null : (dropoffLongitude ?? this.dropoffLongitude),
      rideType: rideType ?? this.rideType,
      estimatedFare: clearFare ? null : (estimatedFare ?? this.estimatedFare),
      estimatedDistance: clearDistance ? null : (estimatedDistance ?? this.estimatedDistance),
      estimatedMinutes: clearMinutes ? null : (estimatedMinutes ?? this.estimatedMinutes),
      step: step ?? this.step,
      isRequesting: isRequesting ?? this.isRequesting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RideBookingNotifier extends StateNotifier<RideBookingState> {
  RideBookingNotifier(this._ref) : super(const RideBookingState());

  final Ref _ref;

  void setPickup(String address, double lat, double lng) {
    state = state.copyWith(
      pickupAddress: address,
      pickupLatitude: lat,
      pickupLongitude: lng,
      clearError: true,
    );
    _updateEstimate();
  }

  void setDropoff(String address, double lat, double lng) {
    state = state.copyWith(
      dropoffAddress: address,
      dropoffLatitude: lat,
      dropoffLongitude: lng,
      clearError: true,
    );
    _updateEstimate();
  }

  void setRideType(RideType type) {
    state = state.copyWith(rideType: type);
    _updateEstimate();
  }

  void setStep(BookingStep step) {
    state = state.copyWith(step: step);
  }

  Future<void> _updateEstimate() async {
    if (!state.isReadyToBook) return;
    try {
      final repo = _ref.read(rideRepositoryProvider);
      final estimate = await repo.getFareEstimate(
        pickupLatitude: state.pickupLatitude!,
        pickupLongitude: state.pickupLongitude!,
        dropoffLatitude: state.dropoffLatitude!,
        dropoffLongitude: state.dropoffLongitude!,
        rideType: state.rideType,
      );
      state = state.copyWith(
        estimatedFare: estimate['fare'],
        estimatedDistance: estimate['distance'],
        estimatedMinutes: estimate['estimatedMinutes']?.toInt(),
      );
    } catch (_) {}
  }

  Future<Ride?> confirmRide() async {
    if (!state.isReadyToBook) return null;
    state = state.copyWith(isRequesting: true, clearError: true);
    try {
      final repo = _ref.read(rideRepositoryProvider);
      final ride = await repo.requestRide(
        pickupLatitude: state.pickupLatitude!,
        pickupLongitude: state.pickupLongitude!,
        pickupAddress: state.pickupAddress,
        dropoffLatitude: state.dropoffLatitude!,
        dropoffLongitude: state.dropoffLongitude!,
        dropoffAddress: state.dropoffAddress,
        rideType: state.rideType,
      );
      state = state.copyWith(isRequesting: false, step: BookingStep.confirmed);
      _ref.invalidate(activeRideProvider);
      return ride;
    } catch (e) {
      state = state.copyWith(isRequesting: false, error: e.toString());
      return null;
    }
  }

  void reset() {
    state = const RideBookingState();
  }
}

final rideBookingProvider =
    StateNotifierProvider<RideBookingNotifier, RideBookingState>((ref) {
  return RideBookingNotifier(ref);
});

final fareEstimateProvider =
    FutureProvider.family<Map<String, double>, ({double pickupLat, double pickupLng, double dropoffLat, double dropoffLng, RideType rideType})>(
  (ref, params) async {
    final repo = ref.watch(rideRepositoryProvider);
    return repo.getFareEstimate(
      pickupLatitude: params.pickupLat,
      pickupLongitude: params.pickupLng,
      dropoffLatitude: params.dropoffLat,
      dropoffLongitude: params.dropoffLng,
      rideType: params.rideType,
    );
  },
);
