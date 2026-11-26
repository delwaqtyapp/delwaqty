import 'package:delwaqty/features/provider/merchant/presentation/pages/barcode_scanner_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_pos_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/pages/merchant_product_form_page.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../helpers/golden_harness.dart';

void main() {
  setUpAll(() async {
    await loadGoldenFonts(cairoWeights: [400], materialIcons: true);
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
    {
      'id': 'p4',
      'name': 'جبنة رومي قديم',
      'price': 90.0,
      'stock_quantity': 6,
      'is_available': false,
      'barcode': '6223000444',
      'image_url': '',
      'category': 'ألبان',
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

  // --- Review fixes #78/#79/#80 -------------------------------------------

  const scannerMethodChannel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );
  const scannerEventChannel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/event',
  );

  void mockPermission(
    PermissionStatus Function() status, {
    List<PermissionStatus> sequence = const [],
  }) {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionChannel, (call) async {
          if (call.method == 'checkPermissionStatus') {
            final s = calls < sequence.length ? sequence[calls] : status();
            calls++;
            return s.index;
          }
          if (call.method == 'requestPermissions') {
            return <int, int>{Permission.camera.value: status().index};
          }
          if (call.method == 'openAppSettings') {
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null),
    );
  }

  List<String> mockScannerChannels() {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(scannerMethodChannel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'state':
          return 1; // authorized
        case 'start':
          return <String, Object?>{
            'textureId': 1,
            'numberOfCameras': 1,
            'currentTorchState': 0,
            'cameraDirection': 1,
            'size': {'width': 1280.0, 'height': 720.0},
          };
        default:
          return null;
      }
    });
    // EventChannel uses listen/cancel over the same-named method channel.
    messenger.setMockMethodCallHandler(scannerEventChannel, (call) async {
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(scannerMethodChannel, null);
      messenger.setMockMethodCallHandler(scannerEventChannel, null);
    });
    return calls;
  }

  Future<void> emitBarcode(String code) async {
    const codec = StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'dev.steenbakker.mobile_scanner/scanner/event',
          codec.encodeSuccessEnvelope(<String, Object?>{
            'name': 'barcode',
            'data': [
              {'rawValue': code, 'format': 32, 'type': 0},
            ],
          }),
          (_) {},
        );
  }

  void useIosTarget() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  Widget buildScannerHost(void Function(String?) onResult) {
    return buildApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async =>
                  onResult(await BarcodeScannerPage.show(context)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    '#78 detection while manual entry is open does not pop the sheet',
    (tester) async {
      useIosTarget();
      mockPermission(() => PermissionStatus.granted);
      final calls = mockScannerChannels();
      String? result;
      var resolved = false;

      usePhone(tester);
      await tester.pumpWidget(
        buildScannerHost((r) {
          result = r;
          resolved = true;
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(MobileScanner), findsOneWidget);

      // Open manual entry: the camera pauses while the sheet is up.
      await tester.tap(find.byIcon(Icons.keyboard_alt_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(calls, contains('stop'));

      // A camera read landing while the sheet is open must be ignored:
      // the sheet stays on top and the scanner does not pop underneath it.
      await emitBarcode('6223000111');
      await tester.pumpAndSettle();
      expect(resolved, isFalse);
      expect(find.byType(TextField), findsOneWidget);

      // Cancelling the sheet resumes the camera.
      calls.clear();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(calls, contains('start'));

      // Detection after the sheet is gone pops the scanner with the code.
      await emitBarcode('6223000111');
      await tester.pumpAndSettle();
      expect(resolved, isTrue);
      expect(result, '6223000111');
    },
  );

  testWidgets('#79 denied -> settings grant -> resume shows the live preview', (
    tester,
  ) async {
    useIosTarget();
    var granted = false;
    mockPermission(
      () => granted
          ? PermissionStatus.granted
          : PermissionStatus.permanentlyDenied,
    );
    mockScannerChannels();

    usePhone(tester);
    await tester.pumpWidget(buildApp(const BarcodeScannerPage()));
    await tester.pumpAndSettle();
    expect(find.text('فتح الإعدادات'), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);

    // Merchant grants camera in Settings, then returns to the app.
    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(MobileScanner), findsOneWidget);
    expect(find.text('فتح الإعدادات'), findsNothing);

    // Manual fallback still usable after the lifecycle round-trip.
    expect(find.byIcon(Icons.keyboard_alt_outlined), findsOneWidget);
  });

  testWidgets(
    '#80 typed unknown digits open quick-create; unavailable scan errors',
    (tester) async {
      usePhone(tester);
      await tester.pumpWidget(buildApp(const MerchantPosPage()));
      await tester.pumpAndSettle();

      final searchField = find.ancestor(
        of: find.byIcon(Icons.search_rounded),
        matching: find.byType(TextField),
      );

      // Unknown numeric code -> routed through the shared handler into
      // quick-create with the barcode attached.
      await tester.enterText(searchField, '9999999');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('منتج جديد لهذا الباركود'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // A barcode matching an unavailable product says exactly that,
      // instead of falling through to quick-create.
      await tester.enterText(searchField, '6223000444');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('أحد الأصناف لم يعد متاحًا'), findsOneWidget);
      expect(find.text('منتج جديد لهذا الباركود'), findsNothing);

      // Let the first snackbar leave the screen; the next one is queued.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      // A barcode matching an out-of-stock product reports the stock
      // problem, never a success.
      await tester.enterText(searchField, '6223000333');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('الكمية المتوفرة من أحد الأصناف غير كافية'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cart panel stays scrollable with the keyboard open at 390px (golden)',
    (tester) async {
      usePhone(tester);
      await tester.pumpWidget(buildApp(const MerchantPosPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('شاي ليبتون 25 كيس'));
      await tester.pumpAndSettle();

      // Scroll the cart list until the discount field is built, focus it
      // and simulate the open keyboard (280px).
      await tester.dragUntilVisible(
        find.widgetWithText(TextField, 'الخصم'),
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, 'الخصم'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      // The fields below the divider stay reachable by scrolling, and the
      // sticky charge bar remains on screen with the keyboard open.
      await tester.dragUntilVisible(
        find.text('طريقة الدفع'),
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(0, -120),
      );
      // dragUntilVisible stops at the viewport edge; align the field fully
      // inside so nothing is half-cut with the keyboard open.
      await Scrollable.ensureVisible(
        tester.element(
          find.widgetWithText(DropdownButtonFormField<String>, 'طريقة الدفع'),
        ),
        alignment: 0.25,
      );
      await tester.pumpAndSettle();
      expect(find.text('تحصيل'), findsOneWidget);

      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/merchant_pos_keyboard_cart_ar.png'),
      );
    },
  );

  testWidgets('product form lower part shows barcode field and save (golden)', (
    tester,
  ) async {
    usePhone(tester);
    await tester.pumpWidget(buildApp(const MerchantProductFormPage()));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('إنشاء'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('إنشاء'), findsOneWidget);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/merchant_product_form_bottom_ar.png'),
    );
  });
}
