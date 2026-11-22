import 'package:delwaqty/features/provider/merchant/presentation/pages/barcode_scanner_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_pos_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_product_form_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  final products = <Map<String, dynamic>>[
    {
      'id': 'p1',
      'name': 'شاي ليبتون 25 كيس',
      'price': 45.0,
      'stock_quantity': 10,
      'is_available': true,
      'barcode': '6223000111',
      'image_url': '',
      'category': 'مشروبات',
    },
    {
      'id': 'p2',
      'name': 'أرز الضحى 1 كجم',
      'price': 38.5,
      'stock_quantity': 4,
      'is_available': true,
      'barcode': '6223000222',
      'image_url': '',
      'category': 'بقالة',
    },
    {
      'id': 'p3',
      'name': 'زيت عافية 700 مل',
      'price': 72.0,
      'stock_quantity': 0,
      'is_available': true,
      'barcode': '6223000333',
      'image_url': '',
      'category': 'بقالة',
    },
  ];

  Widget buildApp(Widget home) {
    return ProviderScope(
      overrides: [
        providerMerchantIdProvider.overrideWith((_) async => 'm1'),
        merchantProductsProvider.overrideWith((_) async => products),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(fontFamily: 'Cairo'),
        home: RepaintBoundary(key: const ValueKey('capture'), child: home),
      ),
    );
  }

  void usePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('POS renders Arabic RTL with search, scan and product tiles', (
    tester,
  ) async {
    usePhone(tester);
    await tester.pumpWidget(buildApp(const MerchantPosPage()));
    await tester.pumpAndSettle();

    expect(find.text('شاي ليبتون 25 كيس'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);
    final directionality = tester.widget<Directionality>(
      find
          .ancestor(
            of: find.byType(MerchantPosPage),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(directionality.textDirection, TextDirection.rtl);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/merchant_pos_ar.png'),
    );
  });

  testWidgets('submitting a typed barcode adds the product to the cart', (
    tester,
  ) async {
    usePhone(tester);
    await tester.pumpWidget(buildApp(const MerchantPosPage()));
    await tester.pumpAndSettle();

    final searchField = find.ancestor(
      of: find.byIcon(Icons.search_rounded),
      matching: find.byType(TextField),
    );
    await tester.enterText(searchField, '6223000222');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // One cart line with qty 1 and the charged preview total of 38.50.
    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('38.50'), findsWidgets);
  });

  testWidgets('tapping a product adds it to the cart (golden)', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(buildApp(const MerchantPosPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('شاي ليبتون 25 كيس'));
    await tester.pumpAndSettle();

    expect(find.textContaining('45.00'), findsWidgets);
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/merchant_pos_cart_ar.png'),
    );
  });

  testWidgets('product form shows the barcode field with a scan button', (
    tester,
  ) async {
    usePhone(tester);
    await tester.pumpWidget(buildApp(const MerchantProductFormPage()));
    await tester.pumpAndSettle();

    expect(find.text('الباركود'), findsWidgets);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/merchant_product_form_ar.png'),
    );
  });

  testWidgets('scanner falls back to Arabic permission UI without a camera', (
    tester,
  ) async {
    // Unanswered platform channels hang forever in widget tests; answer the
    // permission channel the way a camera-less device would.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') {
            return PermissionStatus.permanentlyDenied.index;
          }
          if (call.method == 'requestPermissions') {
            return <int, int>{
              Permission.camera.value: PermissionStatus.permanentlyDenied.index,
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null),
    );

    usePhone(tester);
    await tester.pumpWidget(buildApp(const BarcodeScannerPage()));
    await tester.pump();
    await tester.pumpAndSettle();

    // No camera plugin in tests: the page must explain itself in Arabic and
    // keep the manual-entry path visible instead of showing a dead preview.
    expect(find.text('فتح الإعدادات'), findsOneWidget);
    expect(find.text('إدخال الباركود يدويًا'), findsWidgets);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/barcode_scanner_permission_ar.png'),
    );
  });
}
