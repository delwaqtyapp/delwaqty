import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:delwaqty/features/driver/presentation/widgets/cash_collection_card.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Cairo',
    )..addFont(rootBundle.load('assets/fonts/Cairo-400.ttf'))).load();
  });

  CashCollectionState state({required bool collected}) => CashCollectionState(
    rideId: 'ride-1',
    orderId: 'order-1',
    rideStatus: 'completed',
    paymentMethod: 'cash',
    paymentStatus: collected ? 'paid' : 'pending',
    collected: collected,
    amount: 115,
    currency: 'EGP',
  );

  Widget app({required bool collected, bool busy = false, VoidCallback? onCollect, VoidCallback? onDone}) {
    return RepaintBoundary(
      key: const ValueKey('capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(fontFamily: 'Cairo'),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CashCollectionCard(
              state: state(collected: collected),
              busy: busy,
              onCollect: onCollect ?? () {},
              onDone: onDone ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Arabic uncollected card shows amount and تم التحصيل', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var taps = 0;
    await tester.pumpWidget(app(collected: false, onCollect: () => taps++));
    await tester.pumpAndSettle();

    expect(find.text('مبلغ مطلوب تحصيله'), findsOneWidget);
    expect(find.text('115 EGP'), findsOneWidget);
    expect(find.text('تم التحصيل'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cashCollectButton')));
    expect(taps, 1);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/cash_collection_due_ar.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy state disables the collect button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      app(collected: false, busy: true, onCollect: () => taps++),
    );
    // The busy spinner animates forever, so settle would time out.
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('cashCollectButton')),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('cashCollectButton')));
    expect(taps, 0);
  });

  testWidgets('Arabic collected card confirms and offers Done', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var done = 0;
    await tester.pumpWidget(app(collected: true, onDone: () => done++));
    await tester.pumpAndSettle();

    expect(find.text('تم تحصيل المبلغ'), findsOneWidget);
    expect(find.text('تم التحصيل'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cashCollectionDone')));
    expect(done, 1);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/cash_collected_done_ar.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic retry card shows the error and retries', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var retries = 0;
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(fontFamily: 'Cairo'),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CashCollectionRetryCard(onRetry: () => retries++),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل حالة التحصيل. تحقق من الاتصال وأعد المحاولة.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cashCollectionRetry')));
    expect(retries, 1);

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/cash_collection_retry_ar.png'),
    );
    expect(tester.takeException(), isNull);
  });

  Widget sectionApp(AsyncValue<CashCollectionState?> state) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(fontFamily: 'Cairo'),
      home: Scaffold(
        body: CashCollectionSection(
          state: state,
          busy: false,
          onCollect: () {},
          onDone: () {},
          onRetry: () {},
        ),
      ),
    );
  }

  testWidgets('section fails closed on null and error, hides on non-cash', (
    tester,
  ) async {
    // #84: unknown (null) state → retry card, never silently blank.
    await tester.pumpWidget(sectionApp(const AsyncData(null)));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cashCollectionRetryCard')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cashCollectionCard')), findsNothing);

    // Error → retry card.
    await tester.pumpWidget(
      sectionApp(AsyncError(Exception('x'), StackTrace.empty)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('cashCollectionRetryCard')),
      findsOneWidget,
    );

    // Positively known NON-cash → nothing renders.
    await tester.pumpWidget(
      sectionApp(
        AsyncData(
          CashCollectionState(
            rideId: 'ride-1',
            rideStatus: 'completed',
            paymentMethod: 'wallet',
            paymentStatus: 'paid',
            collected: true,
            currency: 'EGP',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cashCollectionRetryCard')), findsNothing);
    expect(find.byKey(const ValueKey('cashCollectionCard')), findsNothing);

    // Cash → the collection card.
    await tester.pumpWidget(sectionApp(AsyncData(state(collected: false))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cashCollectionCard')), findsOneWidget);
  });
}
