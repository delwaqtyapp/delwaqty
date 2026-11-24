import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/core/constants/storage_keys.dart';
import 'package:delwaqty/data/datasources/local/shared_preferences_service.dart';
import 'package:delwaqty/features/_shared/feature_tour/feature_tour_gate.dart';
import 'package:delwaqty/features/_shared/feature_tour/feature_tour_page.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  );
}

void main() {
  testWidgets('FeatureTourPage pages through steps and finishes', (
    tester,
  ) async {
    var done = false;
    const steps = [
      FeatureTourStep(
        icon: Icons.star,
        color: Colors.teal,
        title: 'Step one',
        body: 'First body',
      ),
      FeatureTourStep(
        icon: Icons.done,
        color: Colors.indigo,
        title: 'Step two',
        body: 'Second body',
      ),
    ];

    await tester.pumpWidget(
      _wrap(FeatureTourPage(steps: steps, onDone: () => done = true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step one'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step two'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
  });

  testWidgets('skip finishes the tour immediately', (tester) async {
    var done = false;
    final steps = buildCustomerTourSteps(
      lookupAppLocalizations(const Locale('en')),
    );

    await tester.pumpWidget(
      _wrap(FeatureTourPage(steps: steps, onDone: () => done = true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
  });

  testWidgets('customer and merchant tours build all localized steps', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final l10n = lookupAppLocalizations(locale);
      final customer = buildCustomerTourSteps(l10n);
      final merchant = buildMerchantProductGuideSteps(l10n);
      expect(customer, hasLength(5));
      expect(merchant, hasLength(5));
      for (final step in [...customer, ...merchant]) {
        expect(step.title, isNotEmpty);
        expect(step.body, isNotEmpty);
      }
    }
  });
  gateAndLayoutTests();
}

const _captureShots = bool.fromEnvironment('CAPTURE_TOUR_SHOTS');

List<FeatureTourStep> _tinySteps(AppLocalizations l10n) => const [
  FeatureTourStep(
    icon: Icons.star,
    color: Colors.teal,
    title: 'T1',
    body: 'B1',
  ),
];

Future<SharedPreferencesService> _prefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferencesService(await SharedPreferences.getInstance());
}

Widget _gateApp({
  required SharedPreferencesService prefs,
  String? Function()? currentUserId,
  bool withNavigatorAway = false,
}) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: FeatureTourGate(
        storageKey: StorageKeys.firstUseTourCustomer,
        stepsBuilder: _tinySteps,
        currentUserId: currentUserId,
        child: withNavigatorAway
            ? Builder(
                builder: (c) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(c).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(body: Text('other')),
                      ),
                    ),
                    child: const Text('go'),
                  ),
                ),
              )
            : const Scaffold(body: Text('home')),
      ),
    ),
  );
}

/// Forces a real unmount+remount: pumping the same widget types would
/// preserve State (gate _scheduled, page _currentPage) across pumps.
Future<void> _reboot(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _showAndDismiss(WidgetTester tester) async {
  await tester.pump(); // post-frame callback
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
  expect(find.byType(FeatureTourPage), findsOneWidget);
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
  expect(find.byType(FeatureTourPage), findsNothing);
}

void main2() {}

void gateAndLayoutTests() {
  group('FeatureTourGate', () {
    testWidgets('shows once and marks seen only after dismissal', (
      tester,
    ) async {
      final prefs = await _prefs();
      const key = '${StorageKeys.firstUseTourCustomer}@user-a';

      await tester.pumpWidget(
        _gateApp(prefs: prefs, currentUserId: () => 'user-a'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourPage), findsOneWidget);
      // Not marked before the user dismisses it.
      expect(prefs.getBool(key: key), isFalse);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(prefs.getBool(key: key), isTrue);

      // Second mount: not shown again.
      await _reboot(tester);
      await tester.pumpWidget(
        _gateApp(prefs: prefs, currentUserId: () => 'user-a'),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourPage), findsNothing);
    });

    testWidgets('seen flags are per account (account switching)', (
      tester,
    ) async {
      final prefs = await _prefs();
      var uid = 'user-a';

      await tester.pumpWidget(_gateApp(prefs: prefs, currentUserId: () => uid));
      await _showAndDismiss(tester);
      expect(
        prefs.getBool(key: '${StorageKeys.firstUseTourCustomer}@user-a'),
        isTrue,
      );

      // Switch account: the new account gets its own first-use tour.
      uid = 'user-b';
      await _reboot(tester);
      await tester.pumpWidget(_gateApp(prefs: prefs, currentUserId: () => uid));
      await _showAndDismiss(tester);
      expect(
        prefs.getBool(key: '${StorageKeys.firstUseTourCustomer}@user-b'),
        isTrue,
      );

      // Back to the first account: still seen.
      uid = 'user-a';
      await _reboot(tester);
      await tester.pumpWidget(_gateApp(prefs: prefs, currentUserId: () => uid));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourPage), findsNothing);
    });

    testWidgets(
      'navigating away before the delayed show cancels it, unmarked',
      (tester) async {
        final prefs = await _prefs();
        await tester.pumpWidget(
          _gateApp(
            prefs: prefs,
            currentUserId: () => 'user-a',
            withNavigatorAway: true,
          ),
        );
        await tester.pump(); // post-frame scheduled
        // Leave the route before the 500ms settle delay elapses.
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(find.text('other'), findsOneWidget);

        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(FeatureTourPage), findsNothing);
        expect(
          prefs.getBool(key: '${StorageKeys.firstUseTourCustomer}@user-a'),
          isFalse,
        );
      },
    );

    testWidgets('unauthenticated: skips quietly and writes nothing', (
      tester,
    ) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        _gateApp(prefs: prefs, currentUserId: () => null),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourPage), findsNothing);
      expect(
        prefs.getBool(key: '${StorageKeys.firstUseTourCustomer}@user-a'),
        isFalse,
      );
    });

    testWidgets('a second presentation while one is open does not stack', (
      tester,
    ) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        _gateApp(prefs: prefs, currentUserId: () => 'user-a'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourPage), findsOneWidget);

      // Manual presentation while the auto one is open joins it.
      final context = tester.element(find.text('home'));
      unawaited(showFeatureTour(context, stepsBuilder: _tinySteps));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourPage), findsOneWidget);

      // Clean up so the shared single-flight guard is released.
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourPage), findsNothing);
    });
  });

  group('FeatureTourPage adaptive layout', () {
    Future<void> loadCairo() async {
      final loader = FontLoader('Cairo')
        ..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Cairo-700.ttf'));
      await loader.load();
    }

    setUpAll(loadCairo);

    testWidgets('Arabic RTL 320x640 @1.6 scale: all 10 slides fit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.view.reset();
      });

      final builders =
          <String, List<FeatureTourStep> Function(AppLocalizations)>{
            'customer': buildCustomerTourSteps,
            'merchant': buildMerchantProductGuideSteps,
          };
      for (final entry in builders.entries) {
        final l10n = lookupAppLocalizations(const Locale('ar'));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(fontFamily: 'Cairo'),
            home: FeatureTourPage(steps: entry.value(l10n), onDone: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          Directionality.of(tester.element(find.byType(FeatureTourPage))),
          TextDirection.rtl,
        );
        for (var i = 0; i < 5; i++) {
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} slide ${i + 1} overflowed',
          );
          if (_captureShots) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                'goldens/tour/${entry.key}_${i + 1}_320_ar16.png',
              ),
            );
          }
          if (i < 4) {
            await tester.tap(find.text('التالي'));
            await tester.pumpAndSettle();
          }
        }
        // Force a fresh State for the next tour's page.
        await _reboot(tester);
      }
    });

    testWidgets('landscape 640x320 @2.0 scale: no overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.view.reset();
      });

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeatureTourPage(
            steps: buildCustomerTourSteps(l10n),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        expect(tester.takeException(), isNull, reason: 'slide ${i + 1}');
        if (i < 4) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
    });
  });
}
