import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/domain/provider_profile.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

AppLocalizations L(String lang) => lookupAppLocalizations(Locale(lang));

ProviderProfile p(String raw) =>
    ProviderProfile.forCategory(ProviderCategory.normalize(raw));

void main() {
  group('category normalization covers every DB vocabulary value', () {
    const merchantTypes = {
      'food': ProviderFamily.restaurant,
      'restaurant': ProviderFamily.restaurant,
      'cafe': ProviderFamily.restaurant,
      'grocery': ProviderFamily.retail,
      'supermarket': ProviderFamily.retail,
      'marketplace': ProviderFamily.retail,
      'electronics': ProviderFamily.retail,
      'fashion': ProviderFamily.retail,
      'flowers': ProviderFamily.retail,
      'bakery': ProviderFamily.retail,
      'general': ProviderFamily.retail,
      'retail': ProviderFamily.retail,
    };
    merchantTypes.forEach((raw, family) {
      test('$raw -> $family', () => expect(p(raw).family, family));
    });

    const serviceTypes = [
      'plumbing',
      'electrical',
      'carpentry',
      'acMaintenance',
      'painting',
      'cleaning',
      'pestControl',
      'applianceRepair',
      'pipeChange',
      'plastering',
      'carpetCleaning',
      'dishRepair',
      'barber',
      'other',
      'home_services',
      'service',
    ];
    for (final raw in serviceTypes) {
      test('$raw is home services', () {
        expect(p(raw).family, ProviderFamily.homeServices);
      });
    }

    test('teacher, doctor and nurse are professionals', () {
      expect(p('teacher').family, ProviderFamily.professional);
      expect(p('doctor').family, ProviderFamily.professional);
      expect(p('nurse').family, ProviderFamily.professional);
      expect(p('teacher').category, ProviderCategory.teacher);
      expect(p('doctor').category, ProviderCategory.healthProfessional);
    });

    test('garbage stays unknown', () {
      expect(p('zzz').family, ProviderFamily.unknown);
      expect(ProviderCategory.normalize(null), ProviderCategory.unknown);
    });
  });

  group('capability matrix', () {
    test('home services never get shop or cashier surfaces', () {
      for (final raw in ['plumbing', 'teacher', 'doctor', 'barber']) {
        final prof = p(raw);
        expect(prof.hasCashier, isFalse, reason: raw);
        expect(prof.hasProducts, isFalse, reason: raw);
        expect(prof.hasStorefront, isFalse, reason: raw);
        expect(prof.hasOrders, isFalse, reason: raw);
        expect(prof.has(ProviderCapability.offers), isFalse, reason: raw);
        expect(prof.has(ProviderCapability.banners), isFalse, reason: raw);
        expect(prof.hasServicesView, isTrue, reason: raw);
        expect(prof.hasBookings, isTrue, reason: raw);
        expect(prof.bookingsAreServiceJobs, isTrue, reason: raw);
      }
    });

    test('shops have the cashier with barcode', () {
      for (final raw in ['grocery', 'electronics', 'bakery']) {
        final prof = p(raw);
        expect(prof.hasCashier, isTrue, reason: raw);
        expect(prof.hasBarcode, isTrue, reason: raw);
        expect(prof.hasProducts, isTrue, reason: raw);
        expect(prof.hasInventory, isTrue, reason: raw);
        expect(prof.hasServicesView, isFalse, reason: raw);
        expect(prof.hasBookings, isFalse, reason: raw);
      }
    });

    test('restaurant has cashier and table bookings but no barcode/stock', () {
      final r = p('restaurant');
      expect(r.hasCashier, isTrue);
      expect(r.hasBookings, isTrue);
      expect(r.bookingsAreServiceJobs, isFalse);
      expect(r.hasBarcode, isFalse);
      expect(r.hasInventory, isFalse);
    });

    test('everyone keeps money, notifications and support', () {
      for (final raw in [
        'restaurant',
        'bakery',
        'grocery',
        'plumbing',
        'teacher',
        'zzz',
        'owner',
      ]) {
        final prof = p(raw);
        expect(prof.has(ProviderCapability.financial), isTrue, reason: raw);
        expect(prof.has(ProviderCapability.support), isTrue, reason: raw);
        expect(prof.has(ProviderCapability.notifications), isTrue, reason: raw);
      }
    });

    test('owner holds every capability', () {
      final owner = p('owner');
      for (final c in ProviderCapability.values) {
        expect(owner.has(c), isTrue, reason: '$c');
      }
    });
  });

  group('bottom tabs per type', () {
    test('shop-like families', () {
      for (final raw in ['restaurant', 'grocery', 'supermarket', 'fashion']) {
        expect(p(raw).tabs, [
          ProviderTabIds.dashboard,
          ProviderTabIds.orders,
          ProviderTabIds.products,
          ProviderTabIds.cashier,
          ProviderTabIds.financial,
        ], reason: raw);
      }
    });

    test('service families', () {
      for (final raw in ['plumbing', 'teacher', 'doctor']) {
        expect(p(raw).tabs, [
          ProviderTabIds.dashboard,
          ProviderTabIds.bookings,
          ProviderTabIds.services,
          ProviderTabIds.financial,
        ], reason: raw);
      }
    });

    test('neutral profile shows no type-specific tab while loading', () {
      expect(ProviderProfile.neutral().tabs, [
        ProviderTabIds.dashboard,
        ProviderTabIds.financial,
      ]);
    });

    test('every tab id of every profile is a known module id', () {
      for (final raw in [
        'restaurant',
        'grocery',
        'plumbing',
        'teacher',
        'zzz',
        'owner',
      ]) {
        for (final t in p(raw).tabs) {
          expect(ProviderTabIds.all, contains(t));
        }
      }
    });
  });

  group('route and drawer guards', () {
    test('plumber cannot open cashier, products, storefront', () {
      final plumber = p('plumbing');
      for (final path in [
        '/provider-cashier',
        '/merchant-dashboard/pos',
        '/provider-products',
        '/merchant-dashboard/products/new',
        '/merchant-dashboard/storefront',
        '/merchant-dashboard/inventory',
        '/provider-orders',
      ]) {
        expect(plumber.allowsRoute(path), isFalse, reason: path);
      }
      expect(plumber.allowsRoute('/provider-services'), isTrue);
      expect(plumber.allowsRoute('/provider-bookings'), isTrue);
      expect(plumber.allowsRoute('/provider-financial-center'), isTrue);
    });

    test('shop cannot open services', () {
      expect(p('grocery').allowsRoute('/provider-services'), isFalse);
      expect(p('grocery').allowsRoute('/provider-cashier'), isTrue);
    });

    test('prefix match does not catch look-alike paths', () {
      expect(p('plumbing').allowsRoute('/provider-products-other'), isTrue);
    });

    test('drawer entries follow capabilities', () {
      expect(p('plumbing').allowsDrawerEntry('merchant-storefront'), isFalse);
      expect(p('plumbing').allowsDrawerEntry('merchant-branches'), isFalse);
      expect(p('plumbing').allowsDrawerEntry('provider-availability'), isTrue);
      expect(p('grocery').allowsDrawerEntry('merchant-storefront'), isTrue);
      expect(p('grocery').allowsDrawerEntry('provider-support'), isTrue);
      expect(p('plumbing').allowsDrawerEntry('some-other-entry'), isTrue);
    });

    test('neutral profile allows only support in the drawer', () {
      final n = ProviderProfile.neutral();
      expect(n.allowsDrawerEntry('provider-support'), isTrue);
      expect(n.allowsDrawerEntry('merchant-storefront'), isFalse);
    });
  });

  group('labels', () {
    test('similar families differ only by wording', () {
      expect(
        p('restaurant').label(ProviderLabel.tabProducts, L('ar')),
        'المنيو',
      );
      expect(p('grocery').label(ProviderLabel.tabProducts, L('ar')), 'الأصناف');
      expect(
        p('fashion').label(ProviderLabel.tabProducts, L('en')),
        'Products',
      );
    });

    test('teacher, doctor and plumber wording', () {
      expect(
        p('teacher').label(ProviderLabel.tabBookings, L('en')),
        'Lesson requests',
      );
      expect(p('teacher').label(ProviderLabel.tabServices, L('ar')), 'دروسي');
      expect(
        p('doctor').label(ProviderLabel.tabBookings, L('en')),
        'Appointments',
      );
      expect(p('plumbing').label(ProviderLabel.tabBookings, L('en')), 'Jobs');
      expect(
        p('plumbing').label(ProviderLabel.tabServices, L('en')),
        'My services',
      );
    });

    test('every label key resolves in both languages for every family', () {
      for (final raw in [
        'restaurant',
        'grocery',
        'bakery',
        'plumbing',
        'teacher',
        'doctor',
        'owner',
        'zzz',
      ]) {
        for (final k in ProviderLabel.values) {
          for (final lang in ['ar', 'en']) {
            expect(
              p(raw).label(k, L(lang)),
              isNotEmpty,
              reason: '$raw $k $lang',
            );
          }
        }
      }
    });

    test('shell config relabels only tab modules', () {
      final cfg = p('teacher').toShellNavConfig();
      expect(
        cfg.labelFor!(ProviderTabIds.bookings, L('en')),
        'Lesson requests',
      );
      expect(cfg.labelFor!(ProviderTabIds.dashboard, L('en')), isNull);
      expect(cfg.labelFor!(ProviderTabIds.financial, L('en')), isNull);
    });
  });
}
