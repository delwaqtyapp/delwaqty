import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/core/theme/app_theme.dart';
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

Widget _app(Widget child, {double textScale = 1.0}) {
  return ProviderScope(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadCairo();
  });

  testWidgets('AdaptiveTileWrap: 3 tiles, 320px, scale 1.0 -> full last row', (
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
    // Last row must stretch: the third tile is full width, not a half orphan.
    final third = tester.getRect(find.byKey(const Key('tile-الطلبات')));
    final wrap = tester.getRect(find.byType(AdaptiveTileWrap));
    expect(third.width, greaterThan(wrap.width * 0.6));
    await expectLater(
      find.byType(AdaptiveTileWrap),
      matchesGoldenFile('goldens/tiles_320_scale20.png'),
    );
  });

  testWidgets('map picker sheet keeps map visible at scale 2.0 on 320x568', (
    tester,
  ) async {
    _smallScreen(tester);
    const mapKey = Key('debug-map-placeholder');
    SmartMapPickerSheet.debugMapOverride = (context) =>
        Container(key: mapKey, color: Colors.green);
    addTearDown(() => SmartMapPickerSheet.debugMapOverride = null);

    await tester.pumpWidget(
      _app(const Scaffold(body: SmartMapPickerSheet()), textScale: 2.0),
    );
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    // The map keeps a usable share of the sheet instead of being squeezed
    // to zero under the search bar.
    final mapRect = tester.getRect(find.byKey(mapKey));
    expect(mapRect.height, greaterThan(120));
    await expectLater(
      find.byType(SmartMapPickerSheet),
      matchesGoldenFile('goldens/map_picker_320_scale20.png'),
    );
  });
}
