import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/features/customer/profile/presentation/app_invitations_provider.dart';
import 'package:delwaqty/features/customer/profile/presentation/pages/app_invitations_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';
import 'package:delwaqty/shared/notifications/notification_route_resolver.dart';

Widget app(
  Future<List<AppFlavor>> Function() load, {
  Future<OtaDownloadResult> Function(AppFlavor, void Function(double))?
  download,
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [
    appInvitationsProvider.overrideWith((ref) => load()),
    if (download != null)
      invitationDownloaderProvider.overrideWithValue(download),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AppInvitationsPage(),
  ),
);
void main() {
  test(
    'parser is strict, deduplicated and excludes customer/unknown roles',
    () {
      expect(parseAppInvitations(null), isEmpty);
      expect(parseAppInvitations({'channels': 'admin'}), isEmpty);
      expect(
        parseAppInvitations({
          'channels': ['owner', 'customer', 12, 'admin', 'admin', 'provider'],
        }),
        [AppFlavor.provider, AppFlavor.admin],
      );
    },
  );
  test('notification opens customer invitation page', () {
    expect(
      NotificationRouteResolver.resolve(
        deepLink: '/profile/app-invitations',
        context: AppContext.customer,
      ),
      '/profile/app-invitations',
    );
  });
  testWidgets('pending/revoked accounts show no download buttons', (
    tester,
  ) async {
    await tester.pumpWidget(app(() async => []));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('no active app invitations'), findsOneWidget);
  });
  testWidgets('errors fail closed with retry', (tester) async {
    await tester.pumpWidget(app(() async => throw StateError('offline')));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets('loading does not expose stale invitation', (tester) async {
    final wait = Completer<List<AppFlavor>>();
    await tester.pumpWidget(app(() => wait.future));
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing);
    wait.complete([]);
    await tester.pumpAndSettle();
  });
  testWidgets('rechecks before install and blocks revoked role', (
    tester,
  ) async {
    var checks = 0;
    var installs = 0;
    await tester.pumpWidget(
      app(
        () async => ++checks == 1 ? [AppFlavor.driver] : [],
        download: (_, _) async {
          installs++;
          return OtaDownloadResult(file: File('x.apk'));
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download the app'));
    await tester.pumpAndSettle();
    expect(checks, 2);
    expect(installs, 0);
    expect(find.byType(FilledButton), findsNothing);
  });
  testWidgets('approved role downloads only selected channel', (tester) async {
    AppFlavor? selected;
    await tester.pumpWidget(
      app(
        () async => [AppFlavor.provider],
        download: (flavor, _) async {
          selected = flavor;
          return OtaDownloadResult(file: File('x.apk'));
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download the app'));
    await tester.pumpAndSettle();
    expect(selected, AppFlavor.provider);
    // The verified file now waits for an explicit Install tap (bug 1).
    expect(find.text('Install'), findsOneWidget);
  });
  testWidgets('installer failure is not reported as success', (tester) async {
    await tester.pumpWidget(
      app(
        () async => [AppFlavor.driver],
        download: (_, _) async =>
            const OtaDownloadResult(error: 'checksum_mismatch'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download the app'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Download could not start'), findsOneWidget);
  });
  testWidgets('Arabic narrow layout fits all approved app cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        () async => [AppFlavor.provider, AppFlavor.driver, AppFlavor.admin],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
