import 'dart:async';

import 'package:delwaqty/features/admin/financial/presentation/providers/admin_financial_providers.dart';
import 'package:delwaqty/features/admin/sanctions/domain/entities/sanction.dart';
import 'package:delwaqty/features/admin/sanctions/domain/repositories/sanctions_repository.dart';
import 'package:delwaqty/features/admin/sanctions/presentation/pages/admin_penalties_policy_page.dart';
import 'package:delwaqty/features/admin/sanctions/presentation/sanctions_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSanctionsRepository implements SanctionsRepository {
  final List<({int days, String? reason})> cancelCalls = [];
  Completer<int>? gate;

  @override
  Future<int> setCancelSuspensionDays(int days, {String? reason}) {
    cancelCalls.add((days: days, reason: reason));
    final gate = this.gate;
    if (gate != null) return gate.future;
    return Future.value(days);
  }

  @override
  Future<int> getCancelSuspensionDays() async => 7;

  @override
  Future<int> getRefusalSuspensionDays() async => 4;

  @override
  Future<int> setRefusalSuspensionDays(int days, {String? reason}) async =>
      days;

  @override
  Future<List<Sanction>> getSanctions({bool? active}) async => const [];

  @override
  Future<List<Sanction>> getUserSanctions(String targetUserId) async =>
      const [];

  @override
  Future<Sanction> getSanctionById(String id) =>
      throw UnimplementedError('not needed in this test');

  @override
  Future<String> issueSanction({
    required String memberId,
    required String sanctionType,
    required String reason,
    int durationDays = 0,
    double amount = 0,
    String? evidenceUrl,
  }) =>
      throw UnimplementedError('not needed in this test');

  @override
  Future<void> revokeSanction({
    required String sanctionId,
    required String reason,
  }) =>
      throw UnimplementedError('not needed in this test');
}

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

  Future<({WidgetTester tester, _FakeSanctionsRepository repo})> pumpPage(
    WidgetTester tester,
  ) async {
    final repo = _FakeSanctionsRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminIsOwnerProvider.overrideWith((ref) async => true),
          sanctionsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const AdminPenaltiesPolicyPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (tester: tester, repo: repo);
  }

  Future<void> openCancelDialog(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.edit_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('تعديل العقوبة'), findsOneWidget);
  }

  testWidgets('save lock: double-tap save triggers exactly one repository call',
      (tester) async {
    final env = await pumpPage(tester);
    env.repo.gate = Completer<int>();

    await openCancelDialog(tester);

    await tester.enterText(find.byType(TextFormField), '10');
    await tester.tap(find.text('حفظ'));
    await tester.pump();
    // Second tap while the first save is still in flight.
    await tester.tap(find.text('حفظ'), warnIfMissed: false);
    await tester.pump();

    env.repo.gate!.complete(10);
    await tester.pumpAndSettle();

    expect(env.repo.cancelCalls, hasLength(1));
    expect(env.repo.cancelCalls.single.days, 10);
    // Dialog closed and the success snackbar is shown.
    expect(find.text('تعديل العقوبة'), findsNothing);
    expect(find.text('تم تحديث العقوبة'), findsOneWidget);
  });

  testWidgets('invalid days (0) shows the range error and never calls the repo',
      (tester) async {
    final env = await pumpPage(tester);

    await openCancelDialog(tester);

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('حفظ'));
    await tester.pump();

    expect(env.repo.cancelCalls, isEmpty);
    expect(find.text('المدة لازم تكون بين 1 و 365 يوم'), findsOneWidget);
    // Dialog stays open for correction.
    expect(find.text('تعديل العقوبة'), findsOneWidget);
  });

  testWidgets('cancel closes the dialog without calling the repo',
      (tester) async {
    final env = await pumpPage(tester);

    await openCancelDialog(tester);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(env.repo.cancelCalls, isEmpty);
    expect(find.text('تعديل العقوبة'), findsNothing);
  });
}
