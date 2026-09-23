import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';
import 'package:delwaqty/features/customer/home/presentation/pages/home_page.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _FakeLocationNotifier extends UserLocationNotifier {
  @override
  Future<UserLocation?> build() async => null;
}

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
      userLocationProvider.overrideWith(_FakeLocationNotifier.new),
      nearbyMerchantsProvider.overrideWith((_) async => <Merchant>[]),
      activeCategoriesProvider.overrideWith((_) async => <PlatformCategory>[]),
      discoveryEntriesProvider.overrideWith((_) async => <DiscoveryEntry>[]),
      activeCampaignsProvider.overrideWith((_) async => <Campaign>[]),
      unreadCountProvider.overrideWith((_) async => 0),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: HomePage(),
    ),
  );
}

void main() {
  const sizes = <(double, double)>[
    (360, 640),
    (360, 800),
    (412, 915),
    (430, 932),
    (800, 1280),
  ];

  for (final (width, height) in sizes) {
    testWidgets(
      'HomePage hero renders without overflow or exceptions at '
      '${width.round()}x${height.round()}',
      (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final trapped = <FlutterErrorDetails>[];
        final prevHandler = FlutterError.onError;
        FlutterError.onError = (details) => trapped.add(details);

        await tester.pumpWidget(_buildTestApp());
        await tester.pump(const Duration(milliseconds: 500));

        FlutterError.onError = prevHandler;

        for (final details in trapped) {
          debugPrint('=====DETAILS-START=====\n${details.toString()}\n=====DETAILS-END=====');
        }

        // Flush all AnimatedFadeIn stagger timers (delay 280ms + index*40ms,
        // up to 560ms across the compact strip) so none are pending at teardown.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(trapped, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  }
}
