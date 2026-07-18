import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:delwaqty/features/driver/data/datasources/remote/supabase_dispatch_data_source.dart';
import 'package:delwaqty/features/driver/data/repositories/dispatch_repository_impl.dart';
import 'package:delwaqty/features/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/driver/domain/repositories/dispatch_repository.dart';
import 'package:delwaqty/features/ride/domain/entities/ride.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final dispatchRepositoryProvider = Provider<DispatchRepository>((ref) {
  return DispatchRepositoryImpl(ref.watch(supabaseDispatchDataSourceProvider));
});

/// Streams live ride offers to the given driver.
final rideOffersProvider =
    StreamProvider.family<List<RideOffer>, String>((ref, driverId) {
  return ref.watch(dispatchRepositoryProvider).watchOffers(driverId);
});

/// Streams the driver's active ride (matched/arrived/inTrip) in realtime.
final activeDriverRideProvider =
    StreamProvider.family<Ride?, String>((ref, driverId) {
  return ref.watch(dispatchRepositoryProvider).watchActiveDriverRide(driverId);
});

/// Aggregated dashboard performance metrics.
final driverStatsProvider =
    FutureProvider.family<DriverStats, String>((ref, driverId) {
  return ref.watch(dispatchRepositoryProvider).getDashboardStats(driverId);
});

/// Driver earnings ledger.
final driverEarningsProvider =
    FutureProvider.family<List<DriverEarning>, String>((ref, driverId) {
  return ref.watch(dispatchRepositoryProvider).getEarnings(driverId);
});

/// Online/offline state and background GPS streaming for a driver.
final driverOnlineProvider =
    StateNotifierProvider.family<DriverOnlineNotifier, AsyncValue<bool>, String>(
  (ref, driverId) => DriverOnlineNotifier(ref, driverId),
);

class DriverOnlineNotifier extends StateNotifier<AsyncValue<bool>> {
  DriverOnlineNotifier(this._ref, this._driverId)
      : super(const AsyncValue.data(false));

  final Ref _ref;
  final String _driverId;
  StreamSubscription<Position>? _positionSub;

  DispatchRepository get _repo => _ref.read(dispatchRepositoryProvider);
  AppLogger get _log => _ref.read(loggerProvider);

  Future<Position?> _currentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      _log.e('Driver position error', e);
      return null;
    }
  }

  Future<void> goOnline() async {
    state = const AsyncValue.loading();
    try {
      final pos = await _currentPosition();
      await _repo.setOnline(
        _driverId,
        true,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      _startTracking();
      state = const AsyncValue.data(true);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> goOffline() async {
    state = const AsyncValue.loading();
    try {
      await _stopTracking();
      await _repo.setOnline(_driverId, false);
      state = const AsyncValue.data(false);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggle() async {
    final online = state.valueOrNull ?? false;
    if (online) {
      await goOffline();
    } else {
      await goOnline();
    }
  }

  void _startTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen((pos) async {
      try {
        await _repo.updateLocation(
          _driverId,
          pos.latitude,
          pos.longitude,
          heading: pos.heading,
          speed: pos.speed,
        );
      } catch (e) {
        _log.e('Driver location push failed', e);
      }
    });
  }

  Future<void> _stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}
