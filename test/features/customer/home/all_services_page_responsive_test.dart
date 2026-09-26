import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/data/repositories/cached_service_booking_repository.dart';
import 'package:delwaqty/data/repositories/category_repository_impl.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home/domain/repositories/platform_category_repository.dart';
import 'package:delwaqty/features/customer/home/presentation/pages/all_services_page.dart';

import '../home_services/helpers/service_samples.dart';

class _MockCachedRepo extends Mock implements CachedServiceBookingRepository {}

class _MockPlatformRepo extends Mock implements PlatformCategoryRepository {}

const _phonePhysicalWidth = 1280.0;
const _phonePhysicalHeight = 2800.0;
const _phoneDpr = 2.975;
const _cutoutTop = 47.4;

final _platformSamples = <PlatformCategory>[
  const PlatformCategory(id: '1', name: 'restaurants', nameAr: 'مطاعم', nameEn: 'Restaurants'),
  const PlatformCategory(id: '2', name: 'grocery', nameAr: 'بقالة', nameEn: 'Groceries'),
  const PlatformCategory(id: '3', name: 'bakery', nameAr: 'مخبز', nameEn: 'Bakeries'),
  const PlatformCategory(id: '4', name: 'pharmacy', nameAr: 'صيدلية', nameEn: 'Pharmacies'),
  const PlatformCategory(id: '5', name: 'vegetables', nameAr: 'خضروات وفواكه', nameEn: 'Produce'),
  const PlatformCategory(id: '6', name: 'cafe', nameAr: 'كافيه', nameEn: 'Cafes'),
];

Widget _buildTestApp(
  _MockCachedRepo repo,
  _MockPlatformRepo platformRepo, {
  Locale locale = const Locale('en'),
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return ProviderScope(
    overrides: [
      cachedServiceBookingRepositoryProvider.overrideWithValue(repo),
      platformCategoryRepositoryProvider.overrideWithValue(platformRepo),
    ],
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
  required _MockPlatformRepo platformRepo,
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
  when(() => platformRepo.getActiveCategories())
      .thenAnswer((_) async => _platformSamples);

  final trapped = <FlutterErrorDetails>[];
  final prevHandler = FlutterError.onError;
  FlutterError.onError = (details) => trapped.add(details);

  await tester.pumpWidget(_buildTestApp(
    repo,
    platformRepo,
    locale: locale,
    padding: padding,
  ));
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
            platformRepo: _MockPlatformRepo(),
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
            platformRepo: _MockPlatformRepo(),
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
            platformRepo: _MockPlatformRepo(),
            size: Size(width, height),
            dpr: 1.0,
          );
        },
      );
    }
  });

  group('AllServicesPage shows every Main Category plus booking services', () {
    testWidgets('both sections render all samples, Arabic locale',
        (tester) async {
      tester.view.physicalSize = const Size(_phonePhysicalWidth, _phonePhysicalHeight);
      tester.view.devicePixelRatio = _phoneDpr;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _MockCachedRepo();
      final platformRepo = _MockPlatformRepo();
      when(() => repo.getCategories()).thenAnswer((_) async => serviceSamples);
      when(() => platformRepo.getActiveCategories())
          .thenAnswer((_) async => _platformSamples);

      await tester.pumpWidget(_buildTestApp(
        repo,
        platformRepo,
        locale: const Locale('ar'),
        padding: const EdgeInsets.only(top: _cutoutTop),
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('الفئات الرئيسية'), findsOneWidget);
      for (final c in _platformSamples) {
        expect(find.text(c.nameAr!), findsOneWidget);
      }
      expect(find.text('خدمات وحجز'), findsOneWidget);
      for (final s in serviceSamples.take(3)) {
        expect(find.text(s.nameAr), findsWidgets);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}