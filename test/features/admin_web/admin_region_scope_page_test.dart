import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/features/admin/domain/entities/admin_region_assignment.dart';
import 'package:delwaqty/features/admin/presentation/providers/admin_region_providers.dart';
import 'package:delwaqty/features/admin/admin_web/presentation/pages/admin_region_scope_page.dart';
import 'package:delwaqty/features/_shared/regions/domain/entities/region.dart';
import 'package:delwaqty/features/_shared/regions/presentation/providers/region_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2026, 8, 15);
  final cairo = Region(
    id: 'r1',
    code: 'EG-CAI',
    type: RegionType.governorate,
    nameAr: 'القاهرة',
    nameEn: 'Cairo',
    createdAt: now,
  );
  final alex = Region(
    id: 'r2',
    code: 'EG-ALX',
    type: RegionType.governorate,
    nameAr: 'الإسكندرية',
    nameEn: 'Alexandria',
    createdAt: now,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    required Override upsertOverride,
  }) async {
    final view = tester.view;
    view.physicalSize = const Size(1600, 900);
    view.devicePixelRatio = 1.0;
    addTearDown(view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminTierUsersProvider.overrideWith(
            (ref) => Future.value([
              {
                'id': 'a1',
                'email': 'admin@example.com',
                'full_name': 'Admin One',
                'role': 'admin',
              },
              {
                'id': 'o1',
                'email': 'owner@example.com',
                'full_name': 'Owner One',
                'role': 'owner',
              },
            ]),
          ),
          governoratesProvider.overrideWith(
            (ref) => Future.value([cairo, alex]),
          ),
          adminRegionAssignmentsProvider.overrideWith((ref, adminId) async {
            if (adminId == 'a1') {
              return [
                AdminRegionAssignment(
                  adminId: 'a1',
                  regionId: 'r1',
                  scope: AdminRegionScope.self,
                  createdAt: now,
                ),
              ];
            }
            return <AdminRegionAssignment>[];
          }),
          upsertOverride,
        ],
        child: const MaterialApp(
          localizationsDelegates: [AppLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AdminRegionScopePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists admin-tier users and shows assignments for selection', (
    tester,
  ) async {
    await pumpPage(
      tester,
      upsertOverride: upsertAdminRegionAssignmentProvider.overrideWith(
        (ref) => ({
          required String adminId,
          required String regionId,
          required AdminRegionScope scope,
        }) async {},
      ),
    );

    expect(find.text('Region Scope'), findsOneWidget);
    expect(find.text('Admin One'), findsOneWidget);
    expect(find.text('Owner One'), findsOneWidget);
    expect(find.text('Select an admin user to manage scope'), findsOneWidget);

    await tester.tap(find.text('Admin One'));
    await tester.pumpAndSettle();

    expect(find.text('Cairo'), findsOneWidget);
    expect(find.text('This region only'), findsOneWidget);
  });

  testWidgets('shows global empty state for admin without assignments', (
    tester,
  ) async {
    await pumpPage(
      tester,
      upsertOverride: upsertAdminRegionAssignmentProvider.overrideWith(
        (ref) => ({
          required String adminId,
          required String regionId,
          required AdminRegionScope scope,
        }) async {},
      ),
    );

    await tester.tap(find.text('Owner One'));
    await tester.pumpAndSettle();

    expect(find.text('No assignments — admin is global'), findsOneWidget);
  });

  testWidgets('adds a new assignment via the form', (tester) async {
    String? capturedAdminId;
    String? capturedRegionId;
    AdminRegionScope? capturedScope;

    await pumpPage(
      tester,
      upsertOverride: upsertAdminRegionAssignmentProvider.overrideWith(
        (ref) => ({
          required String adminId,
          required String regionId,
          required AdminRegionScope scope,
        }) async {
          capturedAdminId = adminId;
          capturedRegionId = regionId;
          capturedScope = scope;
        },
      ),
    );

    await tester.tap(find.text('Admin One'));
    await tester.pumpAndSettle();

    expect(find.text('Cairo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('region-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alexandria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(capturedAdminId, 'a1');
    expect(capturedRegionId, 'r2');
    expect(capturedScope, AdminRegionScope.descendants);
  });
}
