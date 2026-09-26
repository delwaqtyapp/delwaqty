import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/data/repositories/category_repository_impl.dart';
import 'package:delwaqty/features/customer/home/domain/home_domain.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home/domain/repositories/platform_category_repository.dart';
import 'package:delwaqty/features/customer/home/presentation/widgets/app_lifecycle_category_refresh.dart';

class _CountingCategoryRepository implements PlatformCategoryRepository {
  int getActiveCalls = 0;

  @override
  Future<List<PlatformCategory>> getActiveCategories() async {
    getActiveCalls++;
    return const [];
  }

  @override
  Future<List<PlatformCategory>> getAllCategories() async => const [];

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
    throw UnimplementedError();
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
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<String?> uploadCategoryImage({
    required String categoryId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCategoryImage(String imageUrl) async {}
}

void main() {
  testWidgets('resuming the app refetches active categories', (tester) async {
    final repo = _CountingCategoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformCategoryRepositoryProvider.overrideWithValue(repo),
        ],
        child: AppLifecycleCategoryRefresh(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final categoriesAsync = ref.watch(activeCategoriesProvider);
                final count = switch (categoriesAsync) {
                  AsyncData(value: final value) => value.length,
                  _ => -1,
                };
                return Text('count:$count');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.getActiveCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repo.getActiveCalls, 2);
  });
}