import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/_shared/auth/presentation/widgets/role_selection_card.dart';

void main() {
  testWidgets('role cards match in RTL, select, and fit large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Cairo-800.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final capture = GlobalKey();
    int selected = 0;
    double scale = 1;
    const titles = ['عميل', 'تاجر', 'كابتن توصيل', 'مقدم خدمة'];
    const descriptions = [
      'اطلب أكلك دلوقتي',
      'بيع منتجاتك مع دلوقتي',
      'وصّل طلباتك واكسب مع دلوقتي',
      'قدّم خدماتك باحترافية',
    ];
    const colors = [
      Color(0xFF4A90D9),
      Color(0xFF8B5CF6),
      Color(0xFFFF9500),
      Color(0xFF34C759),
    ];
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Cairo', useMaterial3: true),
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: RepaintBoundary(
                  key: capture,
                  child: Scaffold(
                    backgroundColor: const Color(0xFF0A0614),
                    body: SafeArea(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إنشاء حساب',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'الخطوة ١ من ٤',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'اختار نوع حسابك',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'حدد طريقة استخدامك لدلوقتي',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 22),
                              for (var i = 0; i < 4; i += 2) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var j = i; j < i + 2; j++) ...[
                                      if (j > i) const SizedBox(width: 14),
                                      Expanded(
                                        child: RoleSelectionCard(
                                          entranceIndex: j,
                                          icon: RoleCardIcon.values[j],
                                          title: titles[j],
                                          subtitle: descriptions[j],
                                          color: colors[j],
                                          isSelected: selected == j,
                                          onTap: () =>
                                              setState(() => selected = j),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 14),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: FilledButton(
                                  onPressed: () {},
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF5B3DF0),
                                  ),
                                  child: const Text('متابعة'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final cards = find.byType(RoleSelectionCard);
    expect(cards, findsNWidgets(4));
    expect(tester.getSize(cards.at(0)), tester.getSize(cards.at(1)));
    expect(tester.getSize(cards.at(2)), tester.getSize(cards.at(3)));
    expect(
      tester.getTopLeft(cards.at(0)).dx,
      greaterThan(tester.getTopLeft(cards.at(1)).dx),
    );
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${Directory.systemTemp.path}/role-tiles-real-widget.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
    await tester.tap(cards.at(1));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.takeException(), isNull);
    rebuild(() => scale = 1.6);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
