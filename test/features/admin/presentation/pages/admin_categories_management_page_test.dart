import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/repositories/category_repository_impl.dart';
import 'package:delwaqty/domain/entities/user.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/admin/presentation/pages/admin_categories_management_page.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home/domain/repositories/platform_category_repository.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class _FakeCategoryRepository implements PlatformCategoryRepository {
  _FakeCategoryRepository(this.categories);

  final List<PlatformCategory> categories;

  @override
  Future<List<PlatformCategory>> getActiveCategories() async => categories;

  @override
  Future<List<PlatformCategory>> getAllCategories() async => categories;

  @override
  Future<PlatformCategory?> getCategoryById(String id) async => null;

  @override
  Future<PlatformCategory> createCategory({
    required String name,
    String? nameAr,
    String? nameEn,
    String? icon,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    return categories.first;
  }

  @override
  Future<PlatformCategory> updateCategory({
    required String id,
    String? name,
    String? nameAr,
    String? nameEn,
    String? icon,
    int? sortOrder,
    bool? isActive,
    String? imageUrl,
  }) async {
    return categories.first;
  }

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<String?> uploadCategoryImage({
    required String categoryId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    return 'https://example.com/cat.png';
  }

  @override
  Future<void> deleteCategoryImage(String imageUrl) async {}
}

class _RoleAuthNotifier extends AuthStateNotifier {
  _RoleAuthNotifier(this.user);

  final User user;

  @override
  AuthState build() => AuthState.authenticated(user: user);
}

void main() {
  final createdAt = DateTime(2026, 9, 26);
  final category = PlatformCategory(
    id: 'c1',
    name: 'Restaurants',
    nameAr: 'مطاعم',
    nameEn: 'Restaurants',
    imageUrl: 'https://example.com/restaurants.png',
    sortOrder: 1,
    createdAt: createdAt,
  );

  User userWithRole(String role) => User(
        id: 'u1',
        email: 'admin@example.com',
        role: role,
        createdAt: createdAt,
      );

  Future<void> pumpPage(
    WidgetTester tester, {
    required String role,
    required PlatformCategoryRepository repo,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformCategoryRepositoryProvider.overrideWithValue(repo),
          authStateProvider.overrideWith(
            () => _RoleAuthNotifier(userWithRole(role)),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: AdminCategoriesManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders category rows for any logged-in admin', (tester) async {
    await pumpPage(
      tester,
      role: 'admin',
      repo: _FakeCategoryRepository([category]),
    );

    expect(find.text('مطاعم'), findsOneWidget);
    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
  });

  testWidgets('hides image upload/remove controls from non-owner admins', (
    tester,
  ) async {
    await pumpPage(
      tester,
      role: 'admin',
      repo: _FakeCategoryRepository([category]),
    );

    expect(find.byTooltip('Upload image'), findsNothing);
    expect(find.byTooltip('Remove image'), findsNothing);
  });

  testWidgets('shows image upload/remove controls only for the owner', (
    tester,
  ) async {
    await pumpPage(
      tester,
      role: 'owner',
      repo: _FakeCategoryRepository([category]),
    );

    expect(find.byTooltip('Upload image'), findsOneWidget);
    expect(find.byTooltip('Remove image'), findsOneWidget);
    expect(
      find.byTooltip('Remove image'),
      findsOneWidget,
    );
  });
}