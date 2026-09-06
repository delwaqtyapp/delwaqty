import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/fare_quote.dart';
import 'package:delwaqty/features/customer/ride/domain/repositories/ride_repository.dart';
import 'package:delwaqty/features/customer/ride/data/datasources/remote/supabase_ride_data_source.dart';
import 'package:delwaqty/features/customer/ride/data/repositories/ride_repository_impl.dart';

final rideRepositoryImplProvider = Provider<RideRepositoryImpl>((ref) {
  return RideRepositoryImpl(
    ref.watch(supabaseRideDataSourceProvider),
    ref.watch(supabaseClientProvider),
  );
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

final rideStreamProvider = StreamProvider.family<Ride, String>((ref, rideId) {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.watchRide(rideId);
});

enum BookingStep { location, review }

class RideBookingState {
  const RideBookingState({
    this.pickupAddress = '',
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropoffAddress = '',
    this.dropoffLatitude,
    this.dropoffLongitude,
    this.rideType = RideType.economy,
    this.quotes = const [],
    this.isEstimating = false,
    this.promoCode,
    this.promoDiscount = 0,
    this.promoError,
    this.paymentMethod = 'cash',
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
  final List<FareQuote> quotes;
  final bool isEstimating;
  final String? promoCode;
  final double promoDiscount;
  final String? promoError;
  final String paymentMethod;
  final BookingStep step;
  final bool isRequesting;
  final String? error;

  bool get hasPickup => pickupLatitude != null && pickupLongitude != null;
  bool get hasDropoff => dropoffLatitude != null && dropoffLongitude != null;

  bool get isReadyToBook =>
      hasPickup &&
      hasDropoff &&
      pickupAddress.isNotEmpty &&
      dropoffAddress.isNotEmpty &&
      selectedQuote != null;

  FareQuote? get selectedQuote {
    for (final q in quotes) {
      if (q.rideType == rideType) return q;
    }
    return null;
  }

  double get finalFare {
    final base = selectedQuote?.total ?? 0;
    final f = base - promoDiscount;
    return f < 0 ? 0 : f;
  }

  RideBookingState copyWith({
    String? pickupAddress,
    double? pickupLatitude,
    double? pickupLongitude,
    String? dropoffAddress,
    double? dropoffLatitude,
    double? dropoffLongitude,
    RideType? rideType,
    List<FareQuote>? quotes,
    bool? isEstimating,
    String? promoCode,
    bool clearPromoCode = false,
    double? promoDiscount,
    String? promoError,
    bool clearPromoError = false,
    String? paymentMethod,
    BookingStep? step,
    bool? isRequesting,
    String? error,
    bool clearError = false,
  }) {
    return RideBookingState(
      pickupAddress: pickupAddress ?? this.pickupAddress,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      dropoffLatitude: dropoffLatitude ?? this.dropoffLatitude,
      dropoffLongitude: dropoffLongitude ?? this.dropoffLongitude,
      rideType: rideType ?? this.rideType,
      quotes: quotes ?? this.quotes,
      isEstimating: isEstimating ?? this.isEstimating,
      promoCode: clearPromoCode ? null : (promoCode ?? this.promoCode),
      promoDiscount: promoDiscount ?? this.promoDiscount,
      promoError: clearPromoError ? null : (promoError ?? this.promoError),
      paymentMethod: paymentMethod ?? this.paymentMethod,
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
    _refreshQuotes();
  }

  void setDropoff(String address, double lat, double lng) {
    state = state.copyWith(
      dropoffAddress: address,
      dropoffLatitude: lat,
      dropoffLongitude: lng,
      clearError: true,
    );
    _refreshQuotes();
  }

  void setRideType(RideType type) {
    state = state.copyWith(rideType: type);
    _revalidatePromo();
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setStep(BookingStep step) {
    state = state.copyWith(step: step);
  }

  Future<void> _refreshQuotes() async {
    if (!state.hasPickup || !state.hasDropoff) return;
    state = state.copyWith(isEstimating: true, clearError: true);
    try {
      final repo = _ref.read(rideRepositoryProvider);
      final quotes = await repo.getFareQuotes(
        pickupLatitude: state.pickupLatitude!,
        pickupLongitude: state.pickupLongitude!,
        dropoffLatitude: state.dropoffLatitude!,
        dropoffLongitude: state.dropoffLongitude!,
      );
      state = state.copyWith(
        quotes: quotes,
        isEstimating: false,
        step: BookingStep.review,
      );
      await _revalidatePromo();
    } catch (e) {
      state = state.copyWith(isEstimating: false, error: e.toString());
    }
  }

  Future<void> applyPromo(String code) async {
    if (code.trim().isEmpty) return;
    final quote = state.selectedQuote;
    if (quote == null) return;
    state = state.copyWith(clearPromoError: true);
    try {
      final repo = _ref.read(rideRepositoryProvider);
      final result = await repo.validatePromo(code: code.trim(), fare: quote.total);
      if (result.valid) {
        state = state.copyWith(
          promoCode: code.trim().toUpperCase(),
          promoDiscount: result.discount,
          clearPromoError: true,
        );
      } else {
        state = state.copyWith(
          promoDiscount: 0,
          clearPromoCode: true,
          promoError: result.reason ?? 'invalid',
        );
      }
    } catch (e) {
      state = state.copyWith(promoError: e.toString());
    }
  }

  void clearPromo() {
    state = state.copyWith(clearPromoCode: true, promoDiscount: 0, clearPromoError: true);
  }

  Future<void> _revalidatePromo() async {
    final code = state.promoCode;
    if (code == null || code.isEmpty) return;
    await applyPromo(code);
  }

  Future<Ride?> confirmRide() async {
    if (!state.isReadyToBook) return null;
    final quote = state.selectedQuote!;
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
        fare: state.finalFare,
        quote: quote,
        promoCode: state.promoCode,
        discountAmount: state.promoDiscount,
        paymentMethod: state.paymentMethod,
      );
      await repo.dispatchRide(ride.id);
      state = state.copyWith(isRequesting: false);
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
