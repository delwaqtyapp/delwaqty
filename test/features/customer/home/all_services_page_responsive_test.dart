import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';
import 'package:delwaqty/features/customer/home/presentation/pages/all_services_page.dart';

import '../home_services/helpers/service_samples.dart';

class _MockCachedRepo extends Mock implements CachedServiceBookingRepository {}

/// Real DelwaQty phone geometry: 1280x2800 PHYSICAL px @ density 476
/// (override) -> devicePixelRatio 2.975 -> 430.25 x 941.2 logical dp,
/// top cutout 141px -> 47.4 dp top inset. Text scale 1.0.
const _phonePhysicalWidth = 1280.0;
const _phonePhysicalHeight = 2800.0;
const _phoneDpr = 2.975;
const _cutoutTop = 47.4;

Widget _buildTestApp(
  _MockCachedRepo repo, {
  Locale locale = const Locale('en'),
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return ProviderScope(
    overrides: [cachedServiceBookingRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: MediaQuery(
        data: MediaQueryData(padding: padding),
        child: const AllServicesPage(),
      ),
    ),
  );
}

Future<void> _pumpAndAssert(
  WidgetTester tester, {
  required _MockCachedRepo repo,
  Size size = const Size(_phonePhysicalWidth, _phonePhysicalHeight),
  double dpr = _phoneDpr,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  when(() => repo.getCategories()).thenAnswer((_) async => serviceSamples);

  final trapped = <FlutterErrorDetails>[];
  final prevHandler = FlutterError.onError;
  FlutterError.onError = (details) => trapped.add(details);

  await tester.pumpWidget(_buildTestApp(repo, locale: locale, padding: padding));
  await tester.pump(const Duration(milliseconds: 500));

  FlutterError.onError = prevHandler;

  for (final details in trapped) {
    debugPrint(
      '=====DETAILS-START=====\n${details.toString()}\n=====DETAILS-END=====',
    );
  }

  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  expect(trapped, isEmpty);
}

void main() {
  group('AllServicesPage at real device geometry '
      '(1280x2800 @ dpr $_phoneDpr = 430x941 logical)', () {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets(
        'no overflow, textScale 1.0, ${locale.languageCode}',
        (tester) async {
          await _pumpAndAssert(
            tester,
            repo: _MockCachedRepo(),
            locale: locale,
            padding: const EdgeInsets.only(top: _cutoutTop),
          );
        },
      );

      testWidgets(
        'no overflow, textScale 1.3, ${locale.languageCode}',
        (tester) async {
          await _pumpAndAssert(
            tester,
            repo: _MockCachedRepo(),
            textScale: 1.3,
            locale: locale,
            padding: const EdgeInsets.only(top: _cutoutTop),
          );
        },
      );
    }
  });

  group('AllServicesPage common form factors (dpr 1.0)', () {
    const sizes = <(double, double)>[
      (360, 640),
      (360, 800),
      (412, 915),
      (430, 932),
      (800, 1280),
    ];

    for (final (width, height) in sizes) {
      testWidgets(
        'no overflow at ${width.round()}x${height.round()}',
        (tester) async {
          await _pumpAndAssert(
            tester,
            repo: _MockCachedRepo(),
            size: Size(width, height),
            dpr: 1.0,
          );
        },
      );
    }
  });
}