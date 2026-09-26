import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';
import 'package:delwaqty/features/customer/home/presentation/pages/home_page.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_provider.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/_shared/campaigns/presentation/campaign_providers.dart';
import 'package:delwaqty/features/_shared/notifications/notifications_module.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/_shared/campaigns/domain/entities/campaign.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';

import '../home_services/helpers/service_samples.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _FakeLocationNotifier extends UserLocationNotifier {
  @override
  Future<UserLocation?> build() async => null;
}

class _MockCachedServiceRepo extends Mock
    implements CachedServiceBookingRepository {}

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

  testWidgets(
    'HomePage hero renders without overflow with a tall status-bar inset '
    '(notch-like device 366x800, top inset 58)',
    (tester) async {
      tester.view.physicalSize = const Size(366, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trapped = <FlutterErrorDetails>[];
      final prevHandler = FlutterError.onError;
      FlutterError.onError = (details) => trapped.add(details);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(_FakeAuthNotifier.new),
            userLocationProvider.overrideWith(_FakeLocationNotifier.new),
            nearbyMerchantsProvider.overrideWith((_) async => <Merchant>[]),
            activeCategoriesProvider.overrideWith(
              (_) async => <PlatformCategory>[],
            ),
            discoveryEntriesProvider.overrideWith(
              (_) async => <DiscoveryEntry>[],
            ),
            activeCampaignsProvider.overrideWith((_) async => <Campaign>[]),
            unreadCountProvider.overrideWith((_) async => 0),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: MediaQuery(
              data: MediaQueryData(
                padding: EdgeInsets.only(top: 58),
                size: Size(366, 800),
              ),
              child: HomePage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      FlutterError.onError = prevHandler;

      for (final details in trapped) {
        debugPrint(
          '=====DETAILS-START=====\n${details.toString()}\n'
          '=====DETAILS-END=====',
        );
      }

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

  testWidgets(
    'HomePage with real data renders without overflow on the real phone '
    '(1280x2800 @ dpr 2.975 = 430x941 logical, cutout 47.4, Arabic)',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2800);
      tester.view.devicePixelRatio = 2.975;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final serviceRepo = _MockCachedServiceRepo();
      when(() => serviceRepo.getCategories())
          .thenAnswer((_) async => serviceSamples);

      final categories = <PlatformCategory>[
        const PlatformCategory(
          id: 'c1',
          name: 'مطاعم',
          nameAr: 'مطاعم',
          nameEn: 'Restaurants',
        ),
        const PlatformCategory(
          id: 'c2',
          name: 'بقالة',
          nameAr: 'بقالة',
          nameEn: 'Groceries',
          sortOrder: 1,
        ),
        const PlatformCategory(
          id: 'c3',
          name: 'مخبز',
          nameAr: 'مخبز',
          nameEn: 'Bakery',
          sortOrder: 2,
        ),
        const PlatformCategory(
          id: 'c4',
          name: 'صيدلية',
          nameAr: 'صيدلية',
          nameEn: 'Pharmacy',
          sortOrder: 3,
        ),
        const PlatformCategory(
          id: 'c5',
          name: 'خضروات وفواكه',
          nameAr: 'خضروات وفواكه',
          nameEn: 'Vegetables and Fruits',
          sortOrder: 4,
        ),
        const PlatformCategory(
          id: 'c6',
          name: 'كافيه',
          nameAr: 'كافيه',
          nameEn: 'Café',
          sortOrder: 5,
        ),
      ];

      final discovery = <DiscoveryEntry>[
        MerchantDiscoveryEntry(
          Merchant(
            id: 'm1',
            name: 'مطعم النيل للمأكولات الشعبية',
            type: MerchantType.restaurant,
            latitude: 30.04,
            longitude: 31.24,
            rating: 4.8,
            ratingCount: 340,
            isOpenNow: true,
            city: 'القاهرة',
            createdAt: DateTime(2024),
          ),
        ),
        ProviderDiscoveryEntry(
          ServiceProvider(
            id: 'p1',
            userId: 'u1',
            name: 'د/ أحمد عبد الرحمن محمد على',
            categoryType: ServiceCategoryType.doctor,
            rating: 4.9,
            ratingCount: 88,
            isVerified: true,
            city: 'القاهرة',
            createdAt: DateTime(2024),
          ),
        ),
      ];

      final trapped = <FlutterErrorDetails>[];
      final prevHandler = FlutterError.onError;
      FlutterError.onError = (details) => trapped.add(details);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(_FakeAuthNotifier.new),
            userLocationProvider.overrideWith(_FakeLocationNotifier.new),
            nearbyMerchantsProvider.overrideWith((_) async => <Merchant>[]),
            activeCategoriesProvider.overrideWith((_) async => categories),
            discoveryEntriesProvider.overrideWith((_) async => discovery),
            activeCampaignsProvider.overrideWith((_) async => <Campaign>[]),
            unreadCountProvider.overrideWith((_) async => 0),
            cachedServiceBookingRepositoryProvider
                .overrideWithValue(serviceRepo),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('ar'),
            home: MediaQuery(
              data: MediaQueryData(
                padding: EdgeInsets.only(top: 47.4),
                size: Size(430.25, 941.2),
              ),
              child: HomePage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      FlutterError.onError = prevHandler;

      for (final details in trapped) {
        debugPrint(
          '=====DETAILS-START=====\n${details.toString()}\n'
          '=====DETAILS-END=====',
        );
      }

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
