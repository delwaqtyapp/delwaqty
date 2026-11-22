import 'package:delwaqty/features/provider/capability/domain/provider_capability.dart';
import 'package:delwaqty/features/provider/capability/presentation/widgets/provider_category_picker.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppLocalizations L(String lang) => lookupAppLocalizations(Locale(lang));

void main() {
  group('providerCategoryLabel', () {
    test('every requestable category resolves in Arabic and English', () {
      for (final lang in ['ar', 'en']) {
        final l10n = L(lang);
        for (final c in kRequestableProviderCategories) {
          final label = providerCategoryLabel(l10n, c);
          expect(label.trim().isNotEmpty, isTrue, reason: '$c ($lang)');
          expect(label, isNot(l10n.other), reason: '$c ($lang) is unmapped');
        }
      }
    });

    test('expected English wording for the professional categories', () {
      final l10n = L('en');
      expect(providerCategoryLabel(l10n, 'teacher'), 'Tutoring');
      expect(providerCategoryLabel(l10n, 'doctor'), 'Doctor Booking');
      expect(providerCategoryLabel(l10n, 'nurse'), 'Nursing');
      expect(providerCategoryLabel(l10n, 'barber'), 'Barber');
      expect(providerCategoryLabel(l10n, 'plumbing'), 'Plumbing');
      expect(providerCategoryLabel(l10n, 'restaurant'), 'Restaurant');
      expect(providerCategoryLabel(l10n, 'pharmacy'), 'Pharmacy');
      expect(providerCategoryLabel(l10n, 'home_services'), 'Home Services');
    });

    test('camelCase backend spellings match snake_case ones', () {
      for (final lang in ['ar', 'en']) {
        final l10n = L(lang);
        for (final pair in [
          ('acMaintenance', 'ac_maintenance'),
          ('pipeChange', 'pipe_change'),
          ('carpetCleaning', 'carpet_cleaning'),
          ('dishRepair', 'dish_repair'),
          ('pestControl', 'pest_control'),
          ('applianceRepair', 'appliance_repair'),
        ]) {
          expect(
            providerCategoryLabel(l10n, pair.$1),
            providerCategoryLabel(l10n, pair.$2),
            reason: '${pair.$1} vs ${pair.$2} ($lang)',
          );
        }
      }
    });

    test('unknown values fall back to Other', () {
      expect(providerCategoryLabel(L('en'), 'zzz'), L('en').other);
      expect(providerCategoryLabel(L('ar'), 'zzz'), L('ar').other);
    });

    test('requestable list has no duplicates and normalizes cleanly', () {
      expect(
        kRequestableProviderCategories.toSet().length,
        kRequestableProviderCategories.length,
      );
      for (final c in kRequestableProviderCategories) {
        expect(
          ProviderCategory.normalize(c),
          isNot(ProviderCategory.unknown),
          reason: c,
        );
      }
    });
  });

  group('isServiceProviderCategory', () {
    test('service categories are services, shops are not', () {
      for (final c in [
        'teacher',
        'doctor',
        'nurse',
        'barber',
        'plumbing',
        'electrical',
        'carpentry',
        'painting',
        'cleaning',
        'acMaintenance',
        'home_services',
      ]) {
        expect(isServiceProviderCategory(c), isTrue, reason: c);
      }
      for (final c in [
        'restaurant',
        'grocery',
        'pharmacy',
        'bakery',
        'electronics',
        'fashion',
      ]) {
        expect(isServiceProviderCategory(c), isFalse, reason: c);
      }
    });
  });

  group('ProviderCategoryPickerField', () {
    Future<void> pumpPicker(
      WidgetTester tester,
      String lang,
      List<String> captured,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) => ProviderCategoryPickerField(
                  l10n: AppLocalizations.of(context),
                  categories: kRequestableProviderCategories,
                  value: 'plumbing',
                  onChanged: captured.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final lang in ['ar', 'en']) {
      testWidgets('320px $lang: opens, lists every category, picks one', (
        tester,
      ) async {
        final captured = <String>[];
        await pumpPicker(tester, lang, captured);
        expect(tester.takeException(), isNull);

        // The selected value shows in the closed field.
        final l10n = L(lang);
        expect(
          find.text(providerCategoryLabel(l10n, 'plumbing')),
          findsOneWidget,
        );

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Every category is listed in the open menu.
        for (final c in kRequestableProviderCategories) {
          expect(
            find.text(
              providerCategoryLabel(l10n, c),
              skipOffstage: false,
            ).evaluate().isNotEmpty,
            isTrue,
            reason: '$c missing from the $lang menu',
          );
        }

        // Pick the last visible row, whatever the scroll offset is: the
        // menu scrolls on a 320px screen, so the visible window varies.
        final items = find.byType(DropdownMenuItem<String>).hitTestable();
        expect(items, findsWidgets);
        final picked = tester.widget<DropdownMenuItem<String>>(items.last);
        await tester.tap(items.last);
        await tester.pumpAndSettle();
        expect(captured, [picked.value]);
        // The chosen label now shows in the closed field.
        expect(
          find.text(providerCategoryLabel(l10n, picked.value!)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
