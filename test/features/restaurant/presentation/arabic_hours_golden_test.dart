import 'package:delwaqty/features/customer/restaurant/domain/entities/working_hours.dart';
import 'package:delwaqty/features/customer/restaurant/presentation/widgets/working_hours_card.dart';
import 'package:delwaqty/features/provider/merchant/presentation/widgets/schedule_window_note.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Cairo-700.ttf')))
        .load();
  });

  WorkingHours row(
    String id,
    int day,
    String open,
    String close, {
    bool closed = false,
  }) => WorkingHours(
    id: id,
    merchantId: 'm',
    dayOfWeek: day,
    openTime: open,
    closeTime: close,
    isClosed: closed,
    createdAt: DateTime(2026),
  );

  Widget app(Widget child) => RepaintBoundary(
    key: const ValueKey('capture'),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(fontFamily: 'Cairo'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    ),
  );

  testWidgets('customer hours card shows overnight and 24h rows in Arabic', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        WorkingHoursCard(
          hours: [
            row('1', 6, '12:00:00', '01:00:00'),
            row('2', 0, '09:00:00', '23:00:00', closed: true),
            row('3', 1, '09:00:00', '23:00:00'),
            row('4', 2, '00:00:00', '00:00:00'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/working_hours_card_ar.png'),
    );
  });

  testWidgets('provider editor captions for overnight and 24h days in Arabic', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        Column(
          children: [
            Card(
              child: SwitchListTile(
                value: true,
                onChanged: (_) {},
                title: const Text('السبت'),
                subtitle: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('12:00 — 01:00'),
                    ScheduleWindowNote(
                      open: '12:00',
                      close: '01:00',
                      closed: false,
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: SwitchListTile(
                value: true,
                onChanged: (_) {},
                title: const Text('الثلاثاء'),
                subtitle: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('00:00 — 00:00'),
                    ScheduleWindowNote(
                      open: '00:00',
                      close: '00:00',
                      closed: false,
                    ),
                  ],
                ),
              ),
            ),
            const Card(
              child: SwitchListTile(
                value: true,
                onChanged: null,
                title: Text('الاثنين'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('09:00 — 23:00'),
                    ScheduleWindowNote(
                      open: '09:00',
                      close: '23:00',
                      closed: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/provider_hours_editor_ar.png'),
    );
  });
}
