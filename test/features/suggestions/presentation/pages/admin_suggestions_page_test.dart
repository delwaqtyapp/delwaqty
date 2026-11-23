import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:delwaqty/features/_shared/suggestions/domain/entities/suggestion.dart';
import 'package:delwaqty/features/_shared/suggestions/domain/repositories/suggestions_repository.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/pages/admin_suggestions_page.dart';
import 'package:delwaqty/features/_shared/suggestions/presentation/suggestions_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _MockSuggestionsRepository extends Mock
    implements SuggestionsRepository {}

Suggestion _suggestion(String id, String subject, {String status = 'pending'}) {
  return Suggestion(
    id: id,
    userId: 'u-$id',
    appRole: 'customer',
    category: 'general',
    subject: subject,
    description: 'description-$id',
    status: status,
    createdAt: DateTime(2026, 11, 23),
  );
}

Widget _buildApp(SuggestionsRepository repo) {
  return ProviderScope(
    overrides: [suggestionsRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: AdminSuggestionsPage(),
    ),
  );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_suggestion('fb', 'fallback'));
  });

  testWidgets('delayed-response filter switch: stale page cannot append '
      'into the new filter (#147)', (tester) async {
    _tallScreen(tester);
    final repo = _MockSuggestionsRepository();
    final stalePage = Completer<List<Suggestion>>();
    final calls = <({String? status, int offset})>[];

    when(
      () => repo.adminListSuggestions(
        status: any(named: 'status'),
        appRole: any(named: 'appRole'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) {
      final status = invocation.namedArguments[#status] as String?;
      final offset = invocation.namedArguments[#offset] as int;
      calls.add((status: status, offset: offset));
      if (status == null) {
        // The 'all' query hangs until the test releases it (slow old response).
        return stalePage.future;
      }
      return Future.value([_suggestion('new1', 'fresh pending row')]);
    });

    await tester.pumpWidget(_buildApp(repo));
    await tester.pump(); // first ('all') load is in flight

    // Switch the filter while the 'all' response is still pending.
    // (No pumpAndSettle: the loading spinner animates indefinitely.)
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('New').last); // 'pending' status label
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('fresh pending row'), findsOneWidget);

    // The stale 'all' response lands late; it must be ignored entirely.
    stalePage.complete([_suggestion('old1', 'stale all-filter row')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('stale all-filter row'), findsNothing);
    expect(find.text('fresh pending row'), findsOneWidget);
    expect(calls, contains((status: null, offset: 0)));
    expect(calls, contains((status: 'pending', offset: 0)));
  });

  testWidgets('refresh after triage fetches fresh data, never a cached '
      'page (#147)', (tester) async {
    _tallScreen(tester);
    final repo = _MockSuggestionsRepository();
    var serverRows = [_suggestion('s1', 'queue row')];
    var listCalls = 0;

    when(
      () => repo.adminListSuggestions(
        status: any(named: 'status'),
        appRole: any(named: 'appRole'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async {
      listCalls++;
      return List.of(serverRows);
    });
    when(
      () => repo.adminUpdateSuggestionStatus(
        any(),
        any(),
        resolutionNote: any(named: 'resolutionNote'),
      ),
    ).thenAnswer((_) async {
      // Triage lands server-side: the row leaves the pending queue.
      serverRows = [];
    });

    await tester.pumpWidget(_buildApp(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('queue row'), findsOneWidget);
    expect(listCalls, 1);

    // Triage the row through the sheet.
    await tester.tap(find.text('queue row'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    verify(
      () => repo.adminUpdateSuggestionStatus(
        's1',
        any(),
        resolutionNote: any(named: 'resolutionNote'),
      ),
    ).called(1);
    // The page reloaded after triage and shows the fresh (now empty) queue.
    expect(listCalls, greaterThan(1));
    expect(find.text('queue row'), findsNothing);

    // Pulling refresh again hits the server again (no cached page).
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(listCalls, greaterThan(2));
  });

  testWidgets('app filter is passed to the server and a changed https link '
      'is saved, an http link is rejected', (tester) async {
    _tallScreen(tester);
    final repo = _MockSuggestionsRepository();
    final apps = <String?>[];
    when(
      () => repo.adminListSuggestions(
        status: any(named: 'status'),
        appRole: any(named: 'appRole'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      apps.add(invocation.namedArguments[#appRole] as String?);
      return [_suggestion('s1', 'a row')];
    });
    when(
      () => repo.adminUpdateSuggestionStatus(
        any(),
        any(),
        resolutionNote: any(named: 'resolutionNote'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.adminSetSuggestionLink(any(), any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(apps, [null]);

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Captain').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(apps.last, 'driver');

    await tester.tap(find.text('a row'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final linkField = find.widgetWithText(
      TextField,
      'Linked issue or task (https link)',
    );
    await tester.enterText(linkField, 'http://insecure.example/1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    verifyNever(() => repo.adminSetSuggestionLink(any(), any()));
    verifyNever(
      () => repo.adminUpdateSuggestionStatus(
        any(),
        any(),
        resolutionNote: any(named: 'resolutionNote'),
      ),
    );

    await tester.enterText(linkField, 'https://github.com/x/y/issues/9');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    verify(
      () =>
          repo.adminSetSuggestionLink('s1', 'https://github.com/x/y/issues/9'),
    ).called(1);
  });
}
