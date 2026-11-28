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

  test('accepts a decimal comma', () {
    expect(_parse(pr: '1,2')!['priority_multiplier'], 1.2);
  });

  test('rejects negatives, non-numbers and out-of-range multipliers', () {
    expect(_parse(base: '-1'), isNull);
    expect(_parse(km: 'abc'), isNull);
    expect(_parse(min: ''), isNull);
    expect(_parse(pr: '0.5'), isNull);
    expect(_parse(ex: '6'), isNull);
    expect(_parse(base: 'NaN'), isNull);
  });

  testWidgets('page lists each pricing row with editable fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
    expect(find.text('Delivery pricing'), findsOneWidget);
    expect(find.text('courier (EGP)'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.text('Save'), findsOneWidget);
  });
}
