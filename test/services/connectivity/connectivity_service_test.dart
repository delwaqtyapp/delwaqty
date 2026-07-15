import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/services/connectivity/connectivity_service.dart';

void main() {
  group('ConnectivityService', () {
    test('initializes with connected status by default', () {
      final service = ConnectivityService();
      expect(service.currentStatus, ConnectivityStatus.connected);
    });

    test('ConnectivityStatus enum has correct values', () {
      expect(ConnectivityStatus.values.length, 2);
      expect(ConnectivityStatus.connected, isNotNull);
      expect(ConnectivityStatus.disconnected, isNotNull);
    });

    test('stream is broadcast and can have multiple listeners', () {
      final service = ConnectivityService();
      expect(
        () {
          service.statusStream.listen((_) {});
          service.statusStream.listen((_) {});
        },
        returnsNormally,
      );
      service.dispose();
    });
  });
}
