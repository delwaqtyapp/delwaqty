import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:delwaqty/core/theme/app_theme.dart';
import 'package:delwaqty/features/customer/commerce/presentation/pages/checkout_page.dart';
import 'package:delwaqty/features/customer/home/presentation/pages/all_services_page.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/customer/location/presentation/widgets/smart_map_picker_sheet.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/adaptive_tile_wrap.dart';

Future<void> _loadCairo() async {
  final loader = FontLoader('Cairo');
  for (final w in [300, 400, 500, 600, 700, 800, 900]) {
    loader.addFont(
      File('assets/fonts/Cairo-$w.ttf')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)),
    );
  }
  await loader.load();
}

class _NoLocation extends UserLocationNotifier {
  @override
  Future<UserLocation?> build() async => null;
}

class _FixedLocation extends UserLocationNotifier {
  @override
  Future<UserLocation?> build() async => UserLocation(
    latitude: 30.0444,
    longitude: 31.2357,
    detailedAddress: 'وسط البلد، القاهرة',
    accuracyMeters: 12.4,
  );
}

Widget _app(
  Widget child, {
  double textScale = 1.0,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.lightTheme(fontFamily: 'Cairo'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    ),
  );
}

void _smallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _tile(String label) => Container(
  key: Key('tile-$label'),
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: const Color(0xFFEDE7FA),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.star_rounded, size: 21),
      const SizedBox(height: 8),
      Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    ],
  ),
);

const _mapKey = Key('debug-map-placeholder');

void _useMapPlaceholder() {
  SmartMapPickerSheet.debugMapOverride = (context) =>
      Container(key: _mapKey, color: Colors.green);
  SmartMapPickerSheet.debugSearchHits = null;
  SmartMapPickerSheet.debugLockingGps = null;
  SmartMapPickerSheet.debugResolvedAddress = null;
  SmartMapPickerSheet.debugAccuracyMeters = null;
}

void _forceResolvedGps() {
  SmartMapPickerSheet.debugLockingGps = false;
  SmartMapPickerSheet.debugAccuracyMeters = 12.4;
  SmartMapPickerSheet.debugResolvedAddress = 'وسط البلد، القاهرة';
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadCairo();
  });
  tearDown(() {
    SmartMapPickerSheet.debugMapOverride = null;
    SmartMapPickerSheet.debugSearchHits = null;
  });

  testWidgets('AdaptiveTileWrap: 3 tiles, 320px, scale 1.0', (tester) async {
    _smallScreen(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: AdaptiveTileWrap(
              children: [_tile('المحفظة'), _tile('المكافآت'), _tile('الطلبات')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(AdaptiveTileWrap),
      matchesGoldenFile('goldens/tiles_320_scale10.png'),
    );
  });

  testWidgets('AdaptiveTileWrap: 3 tiles, 320px, scale 2.0 -> no orphan', (
    tester,
  ) async {
    _smallScreen(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: AdaptiveTileWrap(
              children: [_tile('المحفظة'), _tile('المكافآت'), _tile('الطلبات')],
            ),
          ),
        ),
        textScale: 2.0,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final third = tester.getRect(find.byKey(const Key('tile-الطلبات')));
    final wrap = tester.getRect(find.byType(AdaptiveTileWrap));
    expect(third.width, greaterThan(wrap.width * 0.6));
    await expectLater(
      find.byType(AdaptiveTileWrap),
      matchesGoldenFile('goldens/tiles_320_scale20.png'),
    );
  });

  testWidgets('map picker at 2.0: acquiring state, overlays keep pin clear', (
    tester,
  ) async {
    _smallScreen(tester);
    _useMapPlaceholder();
    await tester.pumpWidget(
      _app(
        const Scaffold(
          resizeToAvoidBottomInset: false,
          body: SmartMapPickerSheet(),
        ),
        textScale: 2.0,
        overrides: [userLocationProvider.overrideWith(_NoLocation.new)],
      ),
    );
    // First frames: GPS detection kicks in (acquiring state).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    final mapRect = tester.getRect(find.byKey(_mapKey));
    expect(mapRect.height, greaterThan(120));

    // GPS action stays inside the map's horizontal bounds...
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(fab.left, greaterThanOrEqualTo(mapRect.left - 1));
    expect(fab.right, lessThanOrEqualTo(mapRect.right + 1));
    // ...and never covers the center pin area.
    final pinZone = Rect.fromCenter(
      center: mapRect.center,
      width: 120,
      height: 120,
    );
    expect(fab.overlaps(pinZone), isFalse);
    final pin = tester.getRect(find.byIcon(Icons.location_on_rounded));
    expect(pinZone.contains(pin.center), isTrue);

    // The acquiring status is rendered OUTSIDE the map (slim strip below),
    // not as a banner over the pin.
    final strip = tester.getRect(find.byType(CircularProgressIndicator).first);
    expect(strip.top, greaterThanOrEqualTo(mapRect.bottom - 1));

    await expectLater(
      find.byType(SmartMapPickerSheet),
      matchesGoldenFile('goldens/map_picker_acquiring_320_scale20.png'),
    );

    // Search field is reachable by scrolling the top region.
    await tester.ensureVisible(find.byType(TextField));
    await tester.pump();
    final field = tester.getRect(find.byType(TextField));
    expect(field.top, greaterThanOrEqualTo(0));
    expect(field.bottom, lessThanOrEqualTo(568));
  });

  testWidgets('map picker at 2.0: resolved state + keyboard open', (
    tester,
  ) async {
    _smallScreen(tester);
    _useMapPlaceholder();
    _forceResolvedGps();
    await tester.pumpWidget(
      _app(
        const Scaffold(
          resizeToAvoidBottomInset: false,
          body: SmartMapPickerSheet(),
        ),
        textScale: 2.0,
        overrides: [userLocationProvider.overrideWith(_FixedLocation.new)],
      ),
    );
    await _settle(tester);
    final settleError = tester.takeException();
    if (settleError != null) {
      // ignore: avoid_print
      print('SETTLE-ERROR: $settleError');
    }
    expect(settleError, isNull);

    final mapRect = tester.getRect(find.byKey(_mapKey));
    expect(mapRect.height, greaterThan(120));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    final pinZone = Rect.fromCenter(
      center: mapRect.center,
      width: 120,
      height: 120,
    );
    expect(fab.overlaps(pinZone), isFalse);

    await expectLater(
      find.byType(SmartMapPickerSheet),
      matchesGoldenFile('goldens/map_picker_resolved_320_scale20.png'),
    );

    // Keyboard open: sheet shrinks into the space above the keyboard.
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.ensureVisible(find.byType(TextField));
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
    final kbError = tester.takeException();
    if (kbError != null) {
      // ignore: avoid_print
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: kbError),
        forceReport: true,
      );
    }
    expect(kbError, isNull);
    final sheet = tester.getRect(find.byType(SmartMapPickerSheet));
    expect(sheet.bottom, lessThanOrEqualTo(568 - 240 + 1));
    await expectLater(
      find.byType(SmartMapPickerSheet),
      matchesGoldenFile('goldens/map_picker_keyboard_320_scale20.png'),
    );
  });

  testWidgets('map picker at 2.0: search results dropdown fits', (
    tester,
  ) async {
    _smallScreen(tester);
    _useMapPlaceholder();
    _forceResolvedGps();
    SmartMapPickerSheet.debugSearchHits = const [
      (title: 'ميدان التحرير', subtitle: 'وسط البلد، القاهرة'),
      (title: 'برج القاهرة', subtitle: 'الزمالك، القاهرة'),
      (title: 'قلعة صلاح الدين', subtitle: 'القلعة، القاهرة'),
    ];
    await tester.pumpWidget(
      _app(
        const Scaffold(
          resizeToAvoidBottomInset: false,
          body: SmartMapPickerSheet(),
        ),
        textScale: 2.0,
        overrides: [userLocationProvider.overrideWith(_FixedLocation.new)],
      ),
    );
    await _settle(tester);
    final settleError = tester.takeException();
    if (settleError != null) {
      // ignore: avoid_print
      print('SETTLE-ERROR: $settleError');
    }
    expect(settleError, isNull);
    final mapRect = tester.getRect(find.byKey(_mapKey));
    expect(mapRect.height, greaterThan(120));
    // Scroll the top region so the search results are actually painted in
    // the golden (they start below the fold at 2.0 on 320px).
    await tester.scrollUntilVisible(
      find.text('ميدان التحرير'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('ميدان التحرير'), findsOneWidget);
    await expectLater(
      find.byType(SmartMapPickerSheet),
      matchesGoldenFile('goldens/map_picker_hits_320_scale20.png'),
    );
  });

  testWidgets('checkout saved-address chips at 2.0 narrow: no clipping', (
    tester,
  ) async {
    _smallScreen(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SavedAddressChipStrip(
            addresses: const [
              {
                'label': 'المنزل',
                'address': 'شارع رمسيس',
                'latitude': 30.05,
                'longitude': 31.24,
              },
              {
                'label': 'العمل',
                'address': 'مدينة نصر',
                'latitude': 30.06,
                'longitude': 31.25,
              },
            ],
            isSelected: (a) => a['label'] == 'المنزل',
            onSelect: (_) {},
          ),
        ),
        textScale: 2.0,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Chips render inside the strip bounds (no vertical clipping).
    final strip = tester.getRect(find.byType(SavedAddressChipStrip));
    final chip = tester.getRect(find.byType(ChoiceChip).first);
    expect(chip.top, greaterThanOrEqualTo(strip.top - 1));
    expect(chip.bottom, lessThanOrEqualTo(strip.bottom + 1));
    await expectLater(
      find.byType(SavedAddressChipStrip),
      matchesGoldenFile('goldens/checkout_chips_320_scale20.png'),
    );
  });

  testWidgets('all-services grid delegate drops columns at 2.0 narrow', (
    tester,
  ) async {
    _smallScreen(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: adaptiveServiceGridDelegate(context),
              itemCount: 6,
              itemBuilder: (_, i) => _tile('خدمة رقم ${i + 1}'),
            ),
          ),
        ),
        textScale: 2.0,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // At 320px and 2.0x the delegate must pick at most 2 columns (one
    // wide readable column is also acceptable) and tiles must not overlap.
    final first = tester.getRect(find.byKey(const Key('tile-خدمة رقم 1')));
    final second = tester.getRect(find.byKey(const Key('tile-خدمة رقم 2')));
    final third = tester.getRect(find.byKey(const Key('tile-خدمة رقم 3')));
    expect(first.width, greaterThanOrEqualTo(120)); // readable width
    final sameRow = (second.top - first.top).abs() < 1;
    if (sameRow) {
      expect(second.left, greaterThanOrEqualTo(first.right - 1));
    }
    expect(third.top, greaterThan(first.top + 1)); // at most 2 columns
    await expectLater(
      find.byType(GridView),
      matchesGoldenFile('goldens/all_services_grid_320_scale20.png'),
    );
  });
}
