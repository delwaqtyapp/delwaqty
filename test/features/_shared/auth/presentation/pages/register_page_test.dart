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
  void rejectProof([String message = 'PHONE_NOT_VERIFIED']) =>
      state = AuthState.error(message: message);
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
  AuthMethods? methods,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_FakeAuthNotifier.new),
      if (methods != null)
        authMethodsProvider.overrideWith((ref) async => methods),
      registerPhoneVerifierProvider.overrideWithValue(
        (context, phone) async => '00000000-0000-4000-8000-000000000008',
      ),
      if (catalog != null)
        providerServicesCatalogProvider.overrideWith((ref) async => catalog),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const RegisterPage(),
    ),
  );
}

void main() {
  testWidgets('provider role lists every real service from the live catalog', (
    tester,
  ) async {
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
  });

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

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('registerStepNext')));
      await tester.tap(find.byKey(const Key('registerStepNext')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'الاسم الكامل'),
        'أحمد',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'رقم الهاتف'),
        '01000000001',
      );
      expect(find.widgetWithText(TextFormField, 'كلمة المرور'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('registerStepNext')));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('registerStepNext')));
      await tester.tap(find.byKey(const Key('registerStepNext')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور'),
        '12345678',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'تأكيد كلمة المرور'),
        '12345678',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('registerStepNext')));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('registerStepNext')));
      await tester.tap(find.byKey(const Key('registerStepNext')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('registerStepNext')));
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
  for (final entry in {
    'PHONE_INVALID': 'Enter a valid phone number',
    'SIGNUP_PROVIDER_NOT_ALLOWED': 'Use your phone number and WhatsApp verification, or continue with Google.',
    'PHONE_EMAIL_MISMATCH': 'The verified number does not match this registration. Check your number and verify it again.',
    'PHONE_MISMATCH': 'The verified number does not match this registration. Check your number and verify it again.',
    'PHONE_ALREADY_REGISTERED': 'This phone number is already registered. Sign in or reset your password.',
    'EMAIL_SIGNUP_NOT_ALLOWED': 'Use your phone number and WhatsApp verification, or continue with Google.',
  }.entries) {
    testWidgets('${entry.key} clears proof and gives localized recovery', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registerStepNext')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full Name'),
        'Test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone number'),
        '01000000001',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify via WhatsApp'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(RegisterPage)),
      ).read(authStateProvider.notifier) as _FakeAuthNotifier;
      notifier.rejectProof(entry.key);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text(entry.key), findsNothing);
    });
  }

  testWidgets('expired signup proof reveals WhatsApp verification again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 892);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registerStepNext')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full Name'),
      'Test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '01000000001',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify via WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    final notifier = ProviderScope.containerOf(
      tester.element(find.byType(RegisterPage)),
    ).read(authStateProvider.notifier) as _FakeAuthNotifier;
    notifier.rejectProof();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
    expect(
      find.widgetWithText(OutlinedButton, 'Verify via WhatsApp'),
      findsOneWidget,
    );
  });

  testWidgets(
    'email mode: email field, no phone, no WhatsApp, no phone proof',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2800);
      tester.view.devicePixelRatio = 2.975;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _buildTestApp(methods: const AuthMethods(email: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('registerStepNext')));
      await tester.tap(find.byKey(const Key('registerStepNext')));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsWidgets);
      expect(find.text('Phone number'), findsNothing);
      expect(find.text('Verify via WhatsApp'), findsNothing);
      expect(find.text('Password'), findsWidgets);
    },
  );

  testWidgets('default (flags off): phone + WhatsApp path unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2800);
    tester.view.devicePixelRatio = 2.975;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('registerStepNext')));
    await tester.tap(find.byKey(const Key('registerStepNext')));
    await tester.pumpAndSettle();
    expect(find.text('Phone number'), findsWidgets);
    expect(find.text('Verify via WhatsApp'), findsOneWidget);
  });
}
