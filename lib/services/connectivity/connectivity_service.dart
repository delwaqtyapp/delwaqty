import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { connected, disconnected }

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final connectivityStreamProvider = StreamProvider<ConnectivityStatus>((ref) {
  return ref.watch(connectivityServiceProvider).statusStream;
});

final connectivityStatusProvider = Provider<ConnectivityStatus>((ref) {
  final asyncStatus = ref.watch(connectivityStreamProvider);
  return asyncStatus.valueOrNull ?? ConnectivityStatus.connected;
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectivityStatus _currentStatus = ConnectivityStatus.connected;

  ConnectivityStatus get currentStatus => _currentStatus;

  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    final newStatus = hasConnection
        ? ConnectivityStatus.connected
        : ConnectivityStatus.disconnected;

    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _controller.add(newStatus);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
