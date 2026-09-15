import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/shared/widgets/delwa_intro_cinematic.dart';

void main() {
  Future<void> pumpScene(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
  }) async {
    final mediaQuery = MediaQueryData(
      size: size,
      devicePixelRatio: 3,
      textScaler: TextScaler.linear(textScale),
      padding: const EdgeInsets.only(top: 24, bottom: 16, left: 0, right: 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: mediaQuery,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: DelwaIntroScene(),
          ),
        ),
      ),
    );
    var elapsed = Duration.zero;
    while (elapsed < const Duration(milliseconds: 5200)) {
      await tester.pump(const Duration(milliseconds: 400));
      elapsed += const Duration(milliseconds: 400);
    }
  }

  final scenarios = <String, Size>{
    'small-320x480': const Size(320, 480),
    'phone-411x900': const Size(411, 900),
    'tall-411x1200': const Size(411, 1200),
    'large-800x1280': const Size(800, 1280),
  };

  scenarios.forEach((name, size) {
    group('DelwaIntroScene on $name', () {
      testWidgets('renders without overflow (scale 1.0)', (tester) async {
        await pumpScene(tester, size: size);
        expect(tester.takeException(), isNull);
      });

      testWidgets('renders without overflow (scale 1.3)', (tester) async {
        await pumpScene(tester, size: size, textScale: 1.3);
        expect(tester.takeException(), isNull);
      });
    });
  });
}