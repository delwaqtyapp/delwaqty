import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/ota/ota_update_dialog.dart';
import 'package:delwaqty/services/ota/ota_update_manager.dart';

class _Fake {
  int downloads = 0;
  int installs = 0;
  bool allowed = false;
  String? installError;
  final file = File('/tmp/ota-test.apk');

  OtaUpdateActions get actions => OtaUpdateActions(
    download: (onProgress) async {
      downloads++;
      onProgress(1);
      return OtaDownloadResult(file: file);
    },
    canInstall: () async => allowed,
    install: (f) async {
      installs++;
      if (installError != null) return installError;
      return allowed ? null : 'needs_install_permission';
    },
  );
}

Future<void> _pump(WidgetTester tester, _Fake fake, {Locale? locale}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale ?? const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => OtaUpdateDialog(
                flavor: AppFlavor.customer,
                result: const OtaCheckResult(
                  current: 1,
                  latest: 2,
                  needsUpdate: true,
                ),
                actions: fake.actions,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
}

void main() {
  testWidgets('permission wait offers Later without hiding Install', (
    tester,
  ) async {
    final fake = _Fake();
    await _pump(tester, fake);
    await tester.tap(find.text('Update now'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Install'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.byType(OtaUpdateDialog), findsNothing);
  });

  testWidgets('permanent installer failure keeps a safe Later escape', (
    tester,
  ) async {
    final fake = _Fake()
      ..allowed = true
      ..installError = 'install_failed';
    await _pump(tester, fake);
    await tester.tap(find.text('Update now'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Later'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.byType(OtaUpdateDialog), findsNothing);
  });

  testWidgets('permission needed: notice stays, resume continues install '
      'without a second download', (tester) async {
    final fake = _Fake();
    await _pump(tester, fake);
    await tester.tap(find.text('Update now'));
    await tester.pump();
    await tester.pump();

    expect(fake.downloads, 1);
    expect(fake.installs, 1);
    // Calm instructions, Install button visible, no error colour text.
    expect(find.text('Install'), findsOneWidget);
    expect(find.textContaining('Allow Delwaqty'), findsOneWidget);
    expect(find.text('Later'), findsNothing);

    // Back from settings without permission: nothing happens, still shown.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(fake.installs, 1);
    expect(find.text('Install'), findsOneWidget);

    // Permission granted, app resumes: installs the same file automatically.
    fake.allowed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(fake.installs, 2);
    expect(fake.downloads, 1);
    expect(find.text('Install'), findsOneWidget);
  });

  testWidgets('Install button reuses the downloaded file', (tester) async {
    final fake = _Fake();
    await _pump(tester, fake);
    await tester.tap(find.text('Update now'));
    await tester.pump();
    await tester.pump();
    fake.allowed = true;
    await tester.tap(find.text('Install'));
    await tester.pump();
    await tester.pump();
    expect(fake.downloads, 1);
    expect(fake.installs, 2);
  });

  testWidgets('notice cannot be dismissed by back or tapping outside once '
      'downloaded', (tester) async {
    final fake = _Fake();
    await _pump(tester, fake);
    await tester.tap(find.text('Update now'));
    await tester.pump();
    await tester.pump();
    await tester.tapAt(const Offset(2, 2));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Install'), findsOneWidget);
  });

  testWidgets('Arabic strings render', (tester) async {
    final fake = _Fake();
    await _pump(tester, fake, locale: const Locale('ar'));
    expect(find.text('تحديث الآن'), findsOneWidget);
  });

  testWidgets('failed download offers retry and later', (tester) async {
    final fake = _Fake();
    final actions = OtaUpdateActions(
      download: (_) async => const OtaDownloadResult(),
      canInstall: () async => true,
      install: (_) async => null,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: OtaUpdateDialog(
          flavor: AppFlavor.customer,
          result: const OtaCheckResult(
            current: 1,
            latest: 2,
            needsUpdate: true,
          ),
          actions: actions,
        ),
      ),
    );
    expect(fake.downloads, 0);
    await tester.tap(find.text('Update now'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });
}
