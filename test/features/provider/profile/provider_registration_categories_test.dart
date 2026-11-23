import 'package:delwaqty/features/customer/home_services/domain/entities/service_category.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:delwaqty/features/provider/capability/presentation/providers/provider_capability_providers.dart';
import 'package:delwaqty/features/provider/capability/presentation/widgets/provider_category_picker.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_storefront_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The provider role is not only home services: doctor, nurse, teacher,
/// barber, plumber... These tests pin the registration catalog, the
/// unprovisioned-account fallback and the storefront editor to that.

void main() {
  group('ProviderCategory.normalize covers the registration catalog', () {
    test('every ServiceCategoryType wire name resolves to a real category', () {
      for (final type in ServiceCategoryType.values) {
        final wire = serviceCategoryTypeToJson(type);
        expect(
          ProviderCategory.normalize(wire),
          isNot(ProviderCategory.unknown),
          reason: 'registration category $wire fell to unknown',
        );
      }
    });

    test('nurse, doctor and clinic are health professionals', () {
      for (final raw in ['nurse', 'doctor', 'clinic']) {
        final c = ProviderCategory.normalize(raw);
        expect(c, ProviderCategory.healthProfessional, reason: raw);
        expect(
          ProviderProfile.familyOf(c),
          ProviderFamily.professional,
          reason: raw,
        );
      }
    });

    test('teacher and tutor are professionals', () {
      for (final raw in ['teacher', 'teachers', 'tutor']) {
        final c = ProviderCategory.normalize(raw);
        expect(c, ProviderCategory.teacher, reason: raw);
        expect(ProviderProfile.familyOf(c), ProviderFamily.professional);
      }
    });

    test('barber and the trade services are home services', () {
      for (final raw in [
        'barber',
        'plumbing',
        'electrical',
        'carpentry',
        'painting',
        'cleaning',
        'acMaintenance',
        'pipeChange',
        'plastering',
        'carpetCleaning',
        'dishRepair',
        'pestControl',
        'applianceRepair',
        'other',
        'home_services',
      ]) {
        expect(
          ProviderProfile.familyOf(ProviderCategory.normalize(raw)),
          ProviderFamily.homeServices,
          reason: raw,
        );
      }
    });

    test('a nurse keeps services and bookings, never a cashier', () {
      final p = ProviderProfile.forCategory(
        ProviderCategory.normalize('nurse'),
      );
      expect(p.hasServicesView, isTrue);
      expect(p.hasBookings, isTrue);
      expect(p.hasCashier, isFalse);
      expect(p.hasProducts, isFalse);
      expect(p.allowsRoute('/provider-services'), isTrue);
      expect(p.allowsRoute('/provider-cashier'), isFalse);
    });
  });

  group('unprovisioned accounts fail closed', () {
    test('a bare provider role never defaults to home services', () {
      for (final role in ['provider', 'PROVIDER', ' provider ', 'merchant']) {
        expect(unprovisionedCategoryForRole(role), 'unknown', reason: role);
      }
      expect(unprovisionedCategoryForRole(null), 'unknown');
    });

    test('an unprovisioned account gets the closed shell', () {
      final p = ProviderProfile.forCategory(
        ProviderCategory.normalize(unprovisionedCategoryForRole('provider')),
      );
      expect(p.tabs, [ProviderTabIds.dashboard, ProviderTabIds.financial]);
      expect(p.allowsRoute('/provider-services'), isFalse);
      expect(p.allowsRoute('/provider-cashier'), isFalse);
      expect(p.allowsRoute('/provider-bookings'), isFalse);
      expect(p.allowsRoute('/provider-financial-center'), isTrue);
    });
  });

  group('storefront editor is generic for the provider role', () {
    test('storefront list covers shops and every service category', () {
      for (final c in kRequestableProviderCategories) {
        expect(
          kStorefrontProviderCategories,
          contains(c),
          reason: '$c missing from the storefront list',
        );
      }
      // Existing shop-only extras stay.
      for (final c in ['cafe', 'other']) {
        expect(kStorefrontProviderCategories, contains(c));
      }
      // Home Services keeps its exact DB key.
      expect(kStorefrontProviderCategories, contains('home_services'));
      expect(kStorefrontProviderCategories, isNot(contains('homeServices')));
    });

    Future<void> pumpStorefront(WidgetTester tester, String type) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storefrontProvider.overrideWith(
              (ref) async =>
                  StorefrontData(id: 'm-1', name: 'Test', type: type),
            ),
            workingHoursProvider.overrideWith(
              (ref) async => <WorkingHoursDay>[],
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const MerchantStorefrontPage(),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    testWidgets('a teacher storefront keeps its type and label', (
      tester,
    ) async {
      await pumpStorefront(tester, 'teacher');
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, 'teacher');
      expect(find.text('Tutoring'), findsOneWidget);
      expect(find.text('Restaurant'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a nurse storefront is not coerced to a shop', (tester) async {
      await pumpStorefront(tester, 'nurse');
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, 'nurse');
      expect(find.text('Nursing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an out-of-list type is preserved, not replaced', (
      tester,
    ) async {
      await pumpStorefront(tester, 'yoga_studio');
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, 'yoga_studio');
      expect(tester.takeException(), isNull);
    });
  });
}
