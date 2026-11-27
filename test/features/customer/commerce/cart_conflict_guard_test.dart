import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:delwaqty/data/repositories/local_cart_repository.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/cart_conflict_guard.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

CartItem _item(String id) => CartItem(
  id: id,
  productId: 'p-$id',
  productName: 'Product $id',
  quantity: 1,
  unitPrice: 10,
  totalPrice: 10,
);

/// Pumps a button that runs the guard and records its result.
Future<void> _pumpGuard(
  WidgetTester tester,
  LocalCartRepository repo,
  String merchantId,
  void Function(bool) onResult,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [cartRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => FilledButton(
              onPressed: () async {
                final result = await confirmCartMerchantSwitch(
                  context: context,
                  ref: ref,
                  merchantId: merchantId,
                );
                onResult(result);
              },
              child: const Text('add'),
            ),
          ),
        ),
      ),
    ),
  );
  // Let the cart provider finish its initial load.
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('same merchant proceeds without any dialog', (tester) async {
    final repo = LocalCartRepository(userId: 'u1');
    await repo.addToCart(
      merchantId: 'm1',
      merchantName: 'Store One',
      item: _item('a'),
    );
    bool? result;
    await _pumpGuard(tester, repo, 'm1', (r) => result = r);
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('different merchant asks first; cancel keeps the old cart', (
    tester,
  ) async {
    final repo = LocalCartRepository(userId: 'u1');
    await repo.addToCart(
      merchantId: 'm1',
      merchantName: 'Store One',
      item: _item('a'),
    );
    bool? result;
    await _pumpGuard(tester, repo, 'm2', (r) => result = r);
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Start a new cart?'), findsOneWidget);
    expect(find.textContaining('Store One'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    final cart = await repo.getCurrentCart();
    expect(cart!.merchantId, 'm1');
    expect(cart.items, hasLength(1));
  });

  testWidgets('different merchant asks first; confirm proceeds', (
    tester,
  ) async {
    final repo = LocalCartRepository(userId: 'u1');
    await repo.addToCart(
      merchantId: 'm1',
      merchantName: 'Store One',
      item: _item('a'),
    );
    bool? result;
    await _pumpGuard(tester, repo, 'm2', (r) => result = r);
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start new cart'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
