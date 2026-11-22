import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/services/domain/provider_service_info.dart';
import 'package:delwaqty/features/provider/services/presentation/providers/provider_service_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_reservations_page.dart';
import 'package:delwaqty/features/provider/services/presentation/pages/provider_services_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// #85/#86: ONE ProviderContainer across two accounts must never serve the
/// previous account's category, tabs, guard, services, prices or bookings.
/// And within one account, two service profiles keep their own services and
/// booking rows.

class _FakeAuth extends AuthStateNotifier {
  _FakeAuth(this._initial);
  AuthState _initial;

  @override
  AuthState build() => _initial;

  void signInAs(String uid) =>
      state = AuthState.authenticated(
        user: User(
          id: uid,
          email: '$uid@test.dev',
          role: 'provider',
          createdAt: DateTime(2026),
        ),
      );
}

class _FakeServiceRepository implements ProviderServiceRepository {
  _FakeServiceRepository({
    required this.servicesBySpId,
    required this.bookingsBySpId,
  });

  final Map<String, List<ProviderServiceInfo>> servicesBySpId;
  final Map<String, List<Map<String, dynamic>>> bookingsBySpId;
  final List<String> serviceCalls = [];
  final List<String> bookingCalls = [];

  @override
  Future<String?> legacyServiceProviderId() async => null;

  @override
  Future<List<ProviderServiceInfo>> servicesFor(String serviceProviderId) {
    serviceCalls.add(serviceProviderId);
    return Future.value(servicesBySpId[serviceProviderId] ?? const []);
  }

  @override
  Future<List<Map<String, dynamic>>> bookingsFor(String serviceProviderId) {
    bookingCalls.add(serviceProviderId);
    return Future.value(bookingsBySpId[serviceProviderId] ?? const []);
  }
}

ProviderBusinessProfile businessProfile(
  String category, {
  String? serviceProviderId,
  String? merchantId,
}) => ProviderBusinessProfile(
  id: 'bp-$category',
  categoryType: category,
  displayName: category,
  status: 'approved',
  merchantId: merchantId,
  serviceProviderId: serviceProviderId,
);

void main() {
  late _FakeAuth auth;
  late _FakeServiceRepository repo;
  late Map<String, ProviderProfilesState> directory;
  late ProviderContainer container;

  const plumbingServices = [
    ProviderServiceInfo(
      categoryType: 'plumbing',
      name: 'سباكة',
      hourlyRate: 150,
      fixedPriceMin: 200,
      fixedPriceMax: 450,
    ),
  ];
  const electricalServices = [
    ProviderServiceInfo(
      categoryType: 'electrical',
      name: 'كهرباء',
      hourlyRate: 180,
    ),
  ];
  final plumbingBookings = [
    {
      'id': 'bk-p1',
      'provider_id': 'sp-plumbing',
      'description': 'تصليح تسريب حمام',
      'status': 'pending',
    },
  ];
  final electricalBookings = [
    {
      'id': 'bk-e1',
      'provider_id': 'sp-electrical',
      'description': 'تركيب نجفة صالون',
      'status': 'confirmed',
    },
    {
      'id': 'bk-e2',
      'provider_id': 'sp-electrical',
      'description': 'فحص عدّاد',
      'status': 'completed',
    },
  ];

  setUp(() {
    auth = _FakeAuth(const AuthState.unauthenticated());
    repo = _FakeServiceRepository(
      servicesBySpId: {
        'sp-plumbing': plumbingServices,
        'sp-electrical': electricalServices,
      },
      bookingsBySpId: {
        'sp-plumbing': plumbingBookings,
        'sp-electrical': electricalBookings,
      },
    );
    directory = {};
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(() => auth),
        // A client is needed because the real category provider watches it;
        // the overridden flows below never let it touch the network.
        supabaseClientProvider.overrideWithValue(
          SupabaseClient('https://offline.invalid', 'anon'),
        ),
        providerProfilesProvider.overrideWith((ref) async {
          final uid = ref.watch(providerUidProvider);
          return directory[uid] ?? const ProviderProfilesState();
        }),
        providerServiceRepositoryProvider.overrideWithValue(repo),
      ],
    );
    // Attach the notifier so later signInAs calls mutate live state.
    container.read(authStateProvider);
    addTearDown(container.dispose);
  });

  Future<ProviderProfile> currentProfile() async {
    await container.read(providerRawCategoryProvider.future);
    return container.read(providerProfileProvider);
  }

  group('account switch (#85): one container, account A then account B', () {
    test('no stale profile, tabs, guard, services, prices or bookings', () async {
      // Account A: plumber.
      directory['uid-a'] = ProviderProfilesState(
        activeCategory: 'plumbing',
        profiles: [businessProfile('plumbing', serviceProviderId: 'sp-plumbing')],
      );
      auth.signInAs('uid-a');

      var profile = await currentProfile();
      expect(profile.family, ProviderFamily.homeServices);
      expect(profile.tabs, [
        ProviderTabIds.dashboard,
        ProviderTabIds.bookings,
        ProviderTabIds.services,
        ProviderTabIds.financial,
      ]);
      expect(profile.allowsRoute('/provider-services'), isTrue);
      expect(profile.allowsRoute('/provider-cashier'), isFalse);

      final aServices = await container.read(providerServiceInfoProvider.future);
      expect(aServices, plumbingServices);
      final aBookings = await container.read(
        providerServiceBookingsProvider.future,
      );
      expect(aBookings, plumbingBookings);
      expect(repo.serviceCalls, ['sp-plumbing']);
      expect(repo.bookingCalls, ['sp-plumbing']);

      // Sign A out, sign B in: a pharmacy shop.
      directory['uid-b'] = ProviderProfilesState(
        activeCategory: 'pharmacy',
        profiles: [businessProfile('pharmacy', merchantId: 'm-1')],
      );
      auth.signInAs('uid-b');

      profile = await currentProfile();
      expect(profile.family, ProviderFamily.pharmacy);
      expect(profile.category, ProviderCategory.pharmacy);
      expect(
        profile.tabs,
        containsAllInOrder([
          ProviderTabIds.dashboard,
          ProviderTabIds.orders,
          ProviderTabIds.products,
          ProviderTabIds.cashier,
          ProviderTabIds.financial,
        ]),
      );
      // B's guard: cashier opens, plumber surfaces close.
      expect(profile.allowsRoute('/provider-cashier'), isTrue);
      expect(profile.allowsRoute('/merchant-dashboard/drugs'), isTrue);
      expect(profile.allowsRoute('/provider-services'), isFalse);
      expect(profile.allowsRoute('/provider-bookings'), isFalse);

      // No stale A data: B has no service row, so the repo is never asked
      // and nothing from sp-plumbing leaks through.
      final bServices = await container.read(providerServiceInfoProvider.future);
      expect(bServices, isEmpty);
      final bBookings = await container.read(
        providerServiceBookingsProvider.future,
      );
      expect(bBookings, isEmpty);
      expect(repo.serviceCalls, ['sp-plumbing']);
      expect(repo.bookingCalls, ['sp-plumbing']);
    });
  });

  group('two service profiles on one account (#86)', () {
    test('services and bookings follow the selected profile', () async {
      directory['uid-c'] = ProviderProfilesState(
        activeCategory: 'plumbing',
        profiles: [
          businessProfile('plumbing', serviceProviderId: 'sp-plumbing'),
          businessProfile('electrical', serviceProviderId: 'sp-electrical'),
        ],
      );
      auth.signInAs('uid-c');

      expect(
        await container.read(providerSelectedServiceProviderIdProvider.future),
        'sp-plumbing',
      );
      expect(
        await container.read(providerServiceInfoProvider.future),
        plumbingServices,
      );
      expect(
        await container.read(providerServiceBookingsProvider.future),
        plumbingBookings,
      );
      expect(repo.serviceCalls, ['sp-plumbing']);
      expect(repo.bookingCalls, ['sp-plumbing']);

      // The provider switches the active service: the RPC now answers
      // electrical. Refresh and every keyed surface must move with it.
      directory['uid-c'] = ProviderProfilesState(
        activeCategory: 'electrical',
        profiles: [
          businessProfile('plumbing', serviceProviderId: 'sp-plumbing'),
          businessProfile('electrical', serviceProviderId: 'sp-electrical'),
        ],
      );
      container.invalidate(providerProfilesProvider);

      expect(
        await container.read(providerSelectedServiceProviderIdProvider.future),
        'sp-electrical',
      );
      final services = await container.read(providerServiceInfoProvider.future);
      expect(services, electricalServices);
      expect(services, isNot(contains(plumbingServices.first)));
      final bookings = await container.read(
        providerServiceBookingsProvider.future,
      );
      expect(bookings, electricalBookings);
      expect(bookings.map((b) => b['provider_id']).toSet(), {'sp-electrical'});
      expect(repo.serviceCalls, ['sp-plumbing', 'sp-electrical']);
      expect(repo.bookingCalls, ['sp-plumbing', 'sp-electrical']);

      // The profile keeps its service-account shape across the switch.
      final profile = await currentProfile();
      expect(profile.family, ProviderFamily.homeServices);
      expect(profile.hasServicesView, isTrue);
    });

    test('unapproved profiles never become the active service target', () async {
      directory['uid-d'] = const ProviderProfilesState(
        activeCategory: 'plumbing',
        profiles: [
          ProviderBusinessProfile(
            id: 'bp-pending',
            categoryType: 'plumbing',
            displayName: 'سباكة',
            status: 'pending',
            serviceProviderId: 'sp-plumbing',
          ),
        ],
      );
      auth.signInAs('uid-d');

      expect(
        await container.read(providerSelectedServiceProviderIdProvider.future),
        isNull,
      );
      expect(await container.read(providerServiceInfoProvider.future), isEmpty);
      expect(repo.serviceCalls, isEmpty);
      expect(repo.bookingCalls, isEmpty);
    });
  });

  group('keyed surfaces (widget)', () {
    Future<void> pumpPage(
      WidgetTester tester,
      Widget page,
      ProviderProfile profile, {
      List<ProviderServiceInfo> services = const [],
      List<Map<String, dynamic>> bookings = const [],
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerProfileProvider.overrideWithValue(profile),
            providerServiceInfoProvider.overrideWith((ref) async => services),
            providerServiceBookingsProvider.overrideWith(
              (ref) async => bookings,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(fontFamily: 'Cairo'),
            home: page,
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('bookings tab shows the selected profile rows only', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const MerchantReservationsPage(
          mode: ReservationsMode.services,
          showBack: false,
        ),
        ProviderProfile.forCategory(ProviderCategory.homeServices),
        bookings: electricalBookings,
      );
      expect(find.text('تركيب نجفة صالون'), findsOneWidget);
      expect(find.text('فحص عدّاد'), findsOneWidget);
      expect(find.text('تصليح تسريب حمام'), findsNothing);
    });

    testWidgets('my services shows the selected profile prices only', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const ProviderServicesPage(),
        ProviderProfile.forCategory(ProviderCategory.homeServices),
        services: electricalServices,
      );
      expect(find.text('كهرباء'), findsOneWidget);
      expect(find.textContaining('180'), findsOneWidget);
      expect(find.text('سباكة'), findsNothing);
      expect(find.textContaining('150'), findsNothing);
    });
  });
}
