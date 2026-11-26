import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared setup for widget golden tests.
///
/// Font weights are passed explicitly per test on purpose: the engine font
/// collection is shared inside one test process, so loading extra weights
/// can change font resolution in unrelated golden tests. Keep each test's
/// weights exactly as before when migrating (no pixel changes).
Future<void> loadGoldenFonts({
  List<int> cairoWeights = const [400],
  bool materialIcons = false,
}) async {
  final cairo = FontLoader('Cairo');
  for (final w in cairoWeights) {
    cairo.addFont(rootBundle.load('assets/fonts/Cairo-$w.ttf'));
  }
  await cairo.load();
  if (materialIcons) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  }
}

/// Fixed logical viewport at devicePixelRatio 1, reset on teardown.
void setGoldenViewport(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double devicePixelRatio = 1,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
