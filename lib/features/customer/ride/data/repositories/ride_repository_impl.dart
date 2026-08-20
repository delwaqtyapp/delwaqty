import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/ride.dart';
import 'package:delwaqty/features/customer/ride/domain/entities/fare_quote.dart';
import 'package:delwaqty/features/customer/ride/domain/repositories/ride_repository.dart';
import 'package:delwaqty/features/customer/ride/data/datasources/remote/supabase_ride_data_source.dart';

class RideRepositoryImpl implements RideRepository {
  RideRepositoryImpl(this._dataSource, this._client);

  final SupabaseRideDataSource _dataSource;
  final SupabaseClient _client;

  String get _riderId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('No authenticated user');
    }
    return id;
  }

  @override
  Future<List<FareQuote>> getFareQuotes({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
  }) {
    return _dataSource.getFareQuotes(
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
    );
  }

  @override
  Future<PromoResult> validatePromo({
    required String code,
    required double fare,
  }) {
    return _dataSource.validatePromo(
      code: code,
      fare: fare,
      userId: _riderId,
    );
  }

  @override
  Future<Ride> requestRide({
    required double pickupLatitude,
    required double pickupLongitude,
    required String pickupAddress,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String dropoffAddress,
    required RideType rideType,
    required double fare,
    required FareQuote quote,
    String? promoCode,
    double discountAmount = 0,
    String paymentMethod = 'cash',
  }) {
    return _dataSource.requestRide(
      riderId: _riderId,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupAddress: pickupAddress,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      dropoffAddress: dropoffAddress,
      rideType: rideType,
      fare: fare,
      quote: quote,
      promoCode: promoCode,
      discountAmount: discountAmount,
      paymentMethod: paymentMethod,
    );
  }

  @override
  Future<List<NearbyDriver>> findNearbyDrivers({
    required double latitude,
    required double longitude,
    required RideType rideType,
  }) {
    return _dataSource.findNearbyDrivers(
      latitude: latitude,
      longitude: longitude,
      rideType: rideType,
    );
  }

  @override
  Future<int> dispatchRide(String rideId) => _dataSource.dispatchRide(rideId);

  @override
  Stream<Ride> watchRide(String rideId) => _dataSource.watchRide(rideId);

  @override
  Future<Ride?> getRide(String rideId) => _dataSource.getRide(rideId);

  @override
  Future<void> cancelRide(String rideId, {String? reason}) {
    return _dataSource.cancelRide(rideId, reason: reason);
  }

  @override
  Future<Ride?> getActiveRide() {
    return _dataSource.getActiveRide(_riderId);
  }

  @override
  Future<List<Ride>> getRideHistory({int limit = 20, int offset = 0}) {
    return _dataSource.getRideHistory(_riderId, limit: limit, offset: offset);
  }

  @override
  Future<void> rateRide(String rideId, int rating, {String? feedback, double? tip}) {
    return _dataSource.rateRide(rideId, rating, feedback: feedback, tip: tip);
  }

  @override
  Future<void> shareTrip(String rideId) {
    return _dataSource.shareTrip(rideId);
  }

  @override
  Future<void> reportIssue(String rideId, String issue) {
    return _dataSource.reportIssue(rideId, issue);
  }
}
