import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delwaqty/shared/widgets/appearance_segmented.dart';

Widget _host(TextDirection dir, String selected, ValueChanged<String> on) {
  return MaterialApp(
    home: Directionality(
      textDirection: dir,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: AppearanceSegmented<String>(
              options: const [
                AppearanceSegmentOption(
                  'en',
                  Icons.translate,
                  'English',
                  glyph: 'Aa',
                ),
                AppearanceSegmentOption(
                  'ar',
                  Icons.language,
                  'Arabic',
                  glyph: 'ع',
                ),
              ],
              selected: selected,
              onChanged: on,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping an option reports it', (tester) async {
    String? picked;
    await tester.pumpWidget(_host(TextDirection.ltr, 'en', (v) => picked = v));
    await tester.tap(find.text('Arabic'));
    expect(picked, 'ar');
  });

  testWidgets('thumb slides to the selected side and mirrors in RTL', (
    tester,
  ) async {
    Future<double> thumbCenter(TextDirection d, String sel) async {
      await tester.pumpWidget(_host(d, sel, (_) {}));
      await tester.pump(const Duration(seconds: 1));
      final box = tester.getRect(find.byType(FractionallySizedBox).first);
      return box.center.dx;
    }

    final ltrFirst = await thumbCenter(TextDirection.ltr, 'en');
    final ltrSecond = await thumbCenter(TextDirection.ltr, 'ar');
    final rtlFirst = await thumbCenter(TextDirection.rtl, 'en');
    expect(ltrSecond, greaterThan(ltrFirst));
    expect(rtlFirst, greaterThan(ltrFirst));
  });
}
