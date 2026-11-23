import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/features/admin/sanctions/presentation/pages/admin_penalties_policy_page.dart';
import 'package:delwaqty/features/admin/sanctions/presentation/sanctions_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Cairo-600.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required bool isOwner,
    int days = 7,
    int refusalDays = 4,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: ProviderScope(
          overrides: [
            adminIsOwnerProvider.overrideWith((ref) async => isOwner),
            cancelSuspensionDaysProvider.overrideWith((ref) async => days),
            refusalSuspensionDaysProvider.overrideWith(
              (ref) async => refusalDays,
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(fontFamily: 'Cairo'),
            home: const AdminPenaltiesPolicyPage(),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // PremiumEmptyState animates continuously; fixed pumps instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('owner sees the general penalties list in Arabic', (
    tester,
  ) async {
    await pumpPage(tester, isOwner: true, days: 7, refusalDays: 4);

    expect(find.text('العقوبات العامة'), findsWidgets);
    expect(find.text('عقوبة الإلغاء المتكرر'), findsOneWidget);
    expect(find.text('عقوبة رفض الاستلام المتكرر'), findsOneWidget);
    expect(find.textContaining('7'), findsWidgets);
    expect(find.textContaining('4'), findsWidgets);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/penalties_policy_owner_ar.png'),
    );
  });

  testWidgets('owner edit dialog in Arabic', (tester) async {
    await pumpPage(tester, isOwner: true, days: 7);

    await tester.tap(find.byIcon(Icons.edit_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('تعديل العقوبة'), findsOneWidget);
    expect(find.text('عقوبة الإلغاء المتكرر'), findsWidgets);
    expect(find.text('مدة الإيقاف (بالأيام)'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/penalties_policy_edit_dialog_ar.png'),
    );
  });

  testWidgets('non-owner admin sees the owner-only notice, no editor', (
    tester,
  ) async {
    await pumpPage(tester, isOwner: false, settle: false);

    expect(
      find.text('قايمة العقوبات العامة متاحة لحساب المالك فقط.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.edit_rounded), findsNothing);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/penalties_policy_non_owner_ar.png'),
    );
  });
}
