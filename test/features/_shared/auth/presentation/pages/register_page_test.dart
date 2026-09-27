import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/presentation/pages/register_page.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

final _catalog = [
  ServiceCategory(
    id: 'plumbing',
    nameAr: 'سباكة',
    nameEn: 'Plumbing',
    type: ServiceCategoryType.plumbing,
    createdAt: DateTime(2024),
  ),
  ServiceCategory(
    id: 'electrical',
    nameAr: 'كهرباء',
    nameEn: 'Electrical',
    type: ServiceCategoryType.electrical,
    createdAt: DateTime(2024),
  ),
  ServiceCategory(
    id: 'doctor',
    nameAr: 'حجز دكتور',
    nameEn: 'Doctor Booking',
    type: ServiceCategoryType.doctor,
    createdAt: DateTime(2024),
  ),
  ServiceCategory(
    id: 'barber',
    nameAr: 'حجز حلاق',
    nameEn: 'Barber',
    type: ServiceCategoryType.barber,
    createdAt: DateTime(2024),
  ),
  ServiceCategory(
    id: 'other',
    nameAr: 'خدمات أخرى',
    nameEn: 'Other Services',
    type: ServiceCategoryType.other,
    createdAt: DateTime(2024),
  ),
];

Widget _buildTestApp({
  List<ServiceCategory>? catalog,
  String locale = 'en',
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
      if (catalog != null)
        providerServicesCatalogProvider.overrideWith((ref) async => catalog),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale),
      home: const RegisterPage(),
    ),
  );
}

void main() {
  testWidgets(
    'provider role lists every real service from the live catalog',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2800);
      tester.view.devicePixelRatio = 2.975;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildTestApp(catalog: _catalog));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Service Provider'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('0 selected'), findsOneWidget);
      expect(find.text('Plumbing'), findsOneWidget);
      expect(find.text('Electrical'), findsOneWidget);
      expect(find.text('Doctor Booking'), findsOneWidget);
      expect(find.text('Barber'), findsOneWidget);
      expect(find.text('Other Services'), findsOneWidget);

      await tester.ensureVisible(find.text('Plumbing'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Plumbing'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1 selected'), findsOneWidget);

      await tester.ensureVisible(find.text('Select all'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Select all'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('5 selected'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RegisterPage)),
      );
      expect(container.read(providerServicesCatalogProvider).value, _catalog);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'full wizard reaches confirmation without overflow at the real phone geometry',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2800);
      tester.view.devicePixelRatio = 2.975;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(_buildTestApp(locale: 'ar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('عميل'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('registerStepNext')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'الاسم الكامل'),
        'أحمد',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'البريد الإلكتروني'),
        'a@b.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور'),
        '12345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'),
        '12345678',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('registerStepNext')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('registerStepNext')));
      await tester.pumpAndSettle();

      expect(find.text('مراجعة وتأكيد'), findsOneWidget);
      expect(find.text('عميل'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('provider services grid fits a narrow phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildTestApp(catalog: _catalog));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Service Provider'));
    await tester.pumpAndSettle();

    expect(find.text('Plumbing'), findsOneWidget);
    expect(find.text('Other Services'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });
}