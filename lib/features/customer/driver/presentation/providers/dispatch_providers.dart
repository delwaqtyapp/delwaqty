import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geolocator/geolocator.dart';

import 'package:delwaqty/features/customer/driver/data/datasources/remote/supabase_dispatch_data_source.dart';
import 'package:delwaqty/features/customer/driver/data/repositories/dispatch_repository_impl.dart';
import 'package:delwaqty/features/customer/driver/domain/entities/driver_stats.dart';
import 'package:delwaqty/features/customer/driver/domain/repositories/dispatch_repository.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

final dispatchRepositoryProvider = Provider<DispatchRepository>((ref) {
  return DispatchRepositoryImpl(ref.watch(supabaseDispatchDataSourceProvider));
});
final driverStatsProvider = FutureProvider.family<DriverStats, String>((
  ref,
  id,
) {
  return ref.watch(dispatchRepositoryProvider).getDashboardStats(id);
});
final driverEarningsProvider =
    FutureProvider.family<List<DriverEarning>, String>((ref, id) {
      return ref.watch(dispatchRepositoryProvider).getEarnings(id);
    });
final driverLivePositionProvider = StateProvider.family<Position?, String>(
  (ref, id) => null,
);

/// Fresh GPS reads, rather than resending cached positions, renew presence.
class DriverPositionSource {
  Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('location_unavailable');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('location_permission_required');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    if (DateTime.now().difference(position.timestamp).abs() >
        const Duration(seconds: 30)) {
      throw StateError('stale_location');
    }
    return position;
  }
}

final driverPositionSourceProvider = Provider<DriverPositionSource>(
  (ref) => DriverPositionSource(),
);
final driverOnlineProvider =
    StateNotifierProvider.family<
      DriverOnlineNotifier,
      AsyncValue<bool>,
      String
    >((ref, id) => DriverOnlineNotifier(ref, id));

/// Foreground lease. Background execution is not assumed: if the OS suspends
/// this app, dispatch eligibility expires on the server after two minutes.
class DriverOnlineNotifier extends StateNotifier<AsyncValue<bool>>
    with WidgetsBindingObserver {
  DriverOnlineNotifier(this._ref, this._driverId)
    : super(const AsyncValue.loading()) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restore());
  }
  final Ref _ref;
  final String _driverId;
  Timer? _heartbeat;
  Position? _lastPosition;
  bool _desiredOnline = false;
  bool _refreshing = false;
  bool _disposed = false;
  int _generation = 0;
  Position? get lastPosition => _lastPosition;
  DispatchRepository get _repo => _ref.read(dispatchRepositoryProvider);

  bool _current(int generation) => !_disposed && generation == _generation;
  void _record(Position position) {
    _lastPosition = position;
    _ref.read(driverLivePositionProvider(_driverId).notifier).state = position;
  }

  Future<void> _restore() async {
    final generation = _generation;
    try {
      final online = await _repo.getOnline(_driverId);
      if (!_current(generation)) return;
      if (online) {
        await goOnline();
      } else {
        state = const AsyncValue.data(false);
      }
    } catch (error, stack) {
      if (_current(generation)) state = AsyncValue.error(error, stack);
    }
  }

  Future<void> setOnline(bool online) => online ? goOnline() : goOffline();
  Future<void> toggle() => setOnline(!_desiredOnline);

  Future<void> goOnline() async {
    final generation = ++_generation;
    _desiredOnline = true;
    _heartbeat?.cancel();
    state = const AsyncValue.loading();
    try {
      final position = await _ref.read(driverPositionSourceProvider).current();
      if (!_current(generation)) return;
      await _repo.setOnline(
        _driverId,
        true,
        lat: position.latitude,
        lng: position.longitude,
      );
      if (!_current(generation)) {
        if (!_disposed && !_desiredOnline)
          await _repo.setOnline(_driverId, false);
        return;
      }
      _record(position);
      state = const AsyncValue.data(true);
      _heartbeat = Timer.periodic(
        const Duration(seconds: 45),
        (_) => unawaited(_renew()),
      );
    } catch (error, stack) {
      if (!_current(generation)) return;
      _desiredOnline = false;
      try {
        await _repo.setOnline(_driverId, false);
      } catch (_) {
        /* Server lease still expires. */
      }
      if (_current(generation)) state = AsyncValue.error(error, stack);
    }
  }

  Future<void> _renew() async {
    if (_refreshing || !_desiredOnline || _disposed) return;
    final generation = _generation;
    _refreshing = true;
    try {
      final position = await _ref.read(driverPositionSourceProvider).current();
      if (!_current(generation) || !_desiredOnline) return;
      await _repo.updateLocation(
        _driverId,
        position.latitude,
        position.longitude,
        heading: position.heading,
        speed: position.speed,
      );
      if (_current(generation)) _record(position);
    } catch (error, stack) {
      if (!_current(generation)) return;
      _ref.read(loggerProvider).e('Driver presence renewal failed', error);
      _heartbeat?.cancel();
      _desiredOnline = false;
      try {
        await _repo.setOnline(_driverId, false);
      } catch (_) {
        /* Lease expires. */
      }
      if (_current(generation)) state = AsyncValue.error(error, stack);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> goOffline() async {
    final generation = ++_generation;
    _desiredOnline = false;
    _heartbeat?.cancel();
    state = const AsyncValue.loading();
    try {
      await _repo.setOnline(_driverId, false);
      if (_current(generation)) state = const AsyncValue.data(false);
    } catch (error, stack) {
      if (_current(generation)) state = AsyncValue.error(error, stack);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && _desiredOnline) {
      unawaited(goOnline());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
