import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:delwaqty/core/deep_link/deep_link_resolver.dart';
import 'package:delwaqty/services/deep_link/deep_link_service.dart';
import 'package:delwaqty/services/logger/app_logger.dart';

class MockAppLinks extends Mock implements AppLinks {}

class MockAppLogger extends Mock implements AppLogger {}

void main() {
  late MockAppLinks mockAppLinks;
  late MockAppLogger mockLogger;

  setUp(() {
    mockAppLinks = MockAppLinks();
    mockLogger = MockAppLogger();
  });

  DeepLinkService buildService(Stream<Uri?>? overrideStream) {
    return DeepLinkService(
      appLinks: mockAppLinks,
      logger: mockLogger,
      overrideStream: overrideStream,
    );
  }

  test('emits loginCallback for a matching deep link', () async {
    when(() => mockAppLinks.getInitialLink()).thenAnswer((_) async => null);

    final controller = StreamController<Uri?>();
    final service = buildService(controller.stream);
    final routes = <DeepLinkRoute>[];
    final sub = service.routes.listen(routes.add);

    service.start();
    controller.add(Uri.parse('io.delwaqty://login-callback'));
    await Future<void>.delayed(Duration.zero);
    controller.close();
    await sub.cancel();
    service.dispose();

    expect(routes, [DeepLinkRoute.loginCallback]);
  });

  test('ignores unknown hosts and foreign schemes', () async {
    when(() => mockAppLinks.getInitialLink()).thenAnswer((_) async => null);

    final controller = StreamController<Uri?>();
    final service = buildService(controller.stream);
    final routes = <DeepLinkRoute>[];
    final sub = service.routes.listen(routes.add);

    service.start();
    controller
      ..add(Uri.parse('io.delwaqty://profile'))
      ..add(Uri.parse('https://delwaqty.app/login'));
    await Future<void>.delayed(Duration.zero);
    controller.close();
    await sub.cancel();
    service.dispose();

    expect(routes, isEmpty);
  });

  test('start is idempotent and ignores null URIs', () async {
    when(() => mockAppLinks.getInitialLink()).thenAnswer((_) async => null);

    final controller = StreamController<Uri?>();
    final service = buildService(controller.stream);
    final routes = <DeepLinkRoute>[];
    final sub = service.routes.listen(routes.add);

    service.start();
    service.start();
    controller
      ..add(null)
      ..add(Uri.parse('io.delwaqty://login-callback?code=abc'));
    await Future<void>.delayed(Duration.zero);
    controller.close();
    await sub.cancel();
    service.dispose();

    expect(routes, [DeepLinkRoute.loginCallback]);
  });

  test('initialRoute returns the classified launching URI', () async {
    when(
      () => mockAppLinks.getInitialLink(),
    ).thenAnswer((_) async => Uri.parse('io.delwaqty://login-callback'));

    final service = buildService(null);
    expect(await service.initialRoute, DeepLinkRoute.loginCallback);
    expect(await service.initialRoute, DeepLinkRoute.loginCallback);
    service.dispose();
  });

  test('initialRoute is null when no deep link launched the app', () async {
    when(() => mockAppLinks.getInitialLink()).thenAnswer((_) async => null);

    final service = buildService(null);
    expect(await service.initialRoute, isNull);
    service.dispose();
  });
}