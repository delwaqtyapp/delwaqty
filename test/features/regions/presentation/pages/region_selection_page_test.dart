import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/regions/domain/entities/region.dart';
import 'package:delwaqty/features/regions/presentation/pages/region_selection_page.dart';
import 'package:delwaqty/features/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

import '../../data/mock_region_repository.dart';

class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated(
    user: User(
      id: 'u1',
      email: 'user@delwaqty.com',
      createdAt: DateTime(2026, 8, 15),
    ),
  );
}

void main() {
  final now = DateTime(2026, 8, 15);

  final cairo = Region(
    id: 'r-cairo',
    code: 'EG-C',
    type: RegionType.governorate,
    nameAr: 'القاهرة',
    nameEn: 'Cairo',
    createdAt: now,
  );
  final giza = Region(
    id: 'r-giza',
    code: 'EG-GZ',
    type: RegionType.governorate,
    nameAr: 'الجيزة',
    nameEn: 'Giza',
    createdAt: now,
  );

  Widget buildTestApp(MockRegionRepository repository) {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_FakeAuthNotifier.new),
        regionRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: RegionSelectionPage(),
      ),
    );
  }

  testWidgets('shows governorates with a loading indicator first', (tester) async {
    await tester.pumpWidget(buildTestApp(MockRegionRepository(
      governorates: [cairo, giza],
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Cairo'), findsOneWidget);
    expect(find.text('Giza'), findsOneWidget);
  });

  testWidgets('marks the currently selected region', (tester) async {
    final repository = MockRegionRepository(
      governorates: [cairo, giza],
      preference: UserRegionPreference(
        userId: 'u1',
        regionId: 'r-cairo',
        source: RegionPreferenceSource.verified,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    final checkTile = find.ancestor(
      of: find.byIcon(Icons.check_circle_rounded),
      matching: find.byType(ListTile),
    );
    expect(find.descendant(of: checkTile, matching: find.text('Cairo')), findsOneWidget);
  });

  testWidgets('search filters the governorate list', (tester) async {
    final repository = MockRegionRepository(
      governorates: [cairo, giza],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'giz');
    await tester.pumpAndSettle();

    expect(find.text('Giza'), findsOneWidget);
    expect(find.text('Cairo'), findsNothing);
  });

  testWidgets('selecting a governorate persists and pops with the region', (tester) async {
    final repository = MockRegionRepository(
      governorates: [cairo, giza],
    );
    Region? popped;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_FakeAuthNotifier.new),
          regionRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    popped = await Navigator.of(context).push<Region>(
                      MaterialPageRoute(
                        builder: (_) => const RegionSelectionPage(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Giza'));
    await tester.pumpAndSettle();

    expect(repository.preference?.regionId, 'r-giza');
    expect(repository.preference?.source, RegionPreferenceSource.manual);
    expect(popped, giza);
    expect(find.byType(RegionSelectionPage), findsNothing);
  });

  testWidgets('shows a failure snack bar when saving fails', (tester) async {
    final repository = MockRegionRepository(
      governorates: [cairo],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    repository.throwOnNextCall(Exception('db down'));
    await tester.tap(find.text('Cairo'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('shows no-results text when nothing matches', (tester) async {
    final repository = MockRegionRepository(
      governorates: [cairo, giza],
    );

    await tester.pumpWidget(buildTestApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No results found'), findsOneWidget);
  });
}
