import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/features/admin/financial/presentation/pages/admin_delivery_pricing_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Map<String, dynamic>? _parse({
  String base = '15',
  String km = '5',
  String kg = '2',
  String min = '20',
  String pr = '1.2',
  String ex = '1.5',
}) => parseDeliveryPricingInput(
  baseFee: base,
  perKm: km,
  perKg: kg,
  minimumFee: min,
  priorityMultiplier: pr,
  expressMultiplier: ex,
  isActive: true,
);

void main() {
  test('accepts the current courier row', () {
    final r = _parse()!;
    expect(r['base_fee'], 15.0);
    expect(r['express_multiplier'], 1.5);
    expect(r['is_active'], true);
  });

  test('comma is a decimal only as the single separator with 1-2 digits', () {
    expect(_parse(pr: '1,2')!['priority_multiplier'], 1.2);
    expect(_parse(base: '1,500'), isNull);
    expect(_parse(base: '1,5,5'), isNull);
    expect(_parse(base: '1.5,5'), isNull);
  });

  test('accepts Arabic-Indic digits and separators', () {
    final r = _parse(base: '١٥', km: '٥٫٥', pr: '١،٢')!;
    expect(r['base_fee'], 15.0);
    expect(r['per_km'], 5.5);
    expect(r['priority_multiplier'], 1.2);
  });

  test('rejects negatives, non-numbers and values above the caps', () {
    expect(_parse(base: '-1'), isNull);
    expect(_parse(km: 'abc'), isNull);
    expect(_parse(min: ''), isNull);
    expect(_parse(pr: '0.5'), isNull);
    expect(_parse(ex: '3.5'), isNull);
    expect(_parse(base: '501'), isNull);
    expect(_parse(km: '51'), isNull);
    expect(_parse(kg: '51'), isNull);
    expect(_parse(base: 'NaN'), isNull);
    expect(
      _parse(base: '500', km: '50', kg: '50', min: '500', pr: '3', ex: '3'),
      isNotNull,
    );
  });

  test('sample fare uses the server formula', () {
    final r = _parse()!;
    expect(sampleDeliveryFare(r), 42.0);
    expect(
      sampleDeliveryFare(_parse(base: '0', km: '1', kg: '0', min: '20')!),
      20.0,
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool canEdit,
    DeliveryPricingSaver? saver,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminCanEditDeliveryPricingProvider.overrideWith(
            (ref) async => canEdit,
          ),
          if (saver != null)
            deliveryPricingSaverProvider.overrideWithValue(saver),
          adminDeliveryPricingRowsProvider.overrideWith(
            (ref) async => [
              {
                'service_type': 'courier',
                'base_fee': 15,
                'per_km': 5,
                'per_kg': 2,
                'minimum_fee': 20,
                'priority_multiplier': 1.2,
                'express_multiplier': 1.5,
                'currency': 'EGP',
                'is_active': true,
              },
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: AdminDeliveryPricingPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('page lists each pricing row with editable fields', (
    tester,
  ) async {
    await pump(tester, canEdit: true);
    expect(find.text('Delivery pricing'), findsOneWidget);
    expect(find.text('courier (EGP)'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('non country admins see read-only fields and no save', (
    tester,
  ) async {
    await pump(tester, canEdit: false);
    expect(find.textContaining('Only country-level admins'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('denied write shows an error and never says Pricing saved', (
    tester,
  ) async {
    await pump(
      tester,
      canEdit: true,
      saver: (_, _) async => throw const DeliveryPricingNotSavedException(),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Sample fare for 5 km'), findsOneWidget);
    expect(find.textContaining('42.00'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Not saved'), findsOneWidget);
    expect(find.text('Pricing saved'), findsNothing);
  });

  testWidgets('successful save reloads fields from the saved row', (
    tester,
  ) async {
    await pump(
      tester,
      canEdit: true,
      saver: (_, d) async => {...d, 'base_fee': 16},
    );
    await tester.enterText(find.byType(TextField).first, '17');
    await tester.tap(find.byType(FilledButton));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Save'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pricing saved'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '16',
    );
  });
}
