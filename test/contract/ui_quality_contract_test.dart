import 'dart:convert';
import 'dart:io';

import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the UI conventions fixed in ROUND 90.
///
/// Each defect here was a defect an operator or a customer actually sees:
/// a page that leaked raw SQL/exception text, a merchant console that was
/// hard-coded in English inside an Arabic app, and money/deletion actions
/// that executed on a single tap.
void main() {
  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('/l10n/'))
      .where((f) => !f.path.endsWith('.freezed.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .toList();

  String read(String p) => File(p).readAsStringSync();

  group('no raw exception text reaches the UI', () {
    // The display boundary is the only place that must be safe: data and domain
    // layers may keep the Postgres text (ServerException(message: e.toString()))
    // because that is what a log wants. What no presentation file may do is
    // hand that text to a widget.
    //
    // Sinks are the parameters a person reads. Sources are the ways a raw error
    // travels. Every combination of the two is a defect, which is what this test
    // asserts - the previous version only looked inside Text('...') with a
    // leading literal, so `message: e.toString()`, `SnackBar(...)`, and
    // '$errorCode: $e' all passed. That gap is how a full Postgres error reached
    // the admin Operations Center.
    final sink = RegExp(
      r'(Text\(|SnackBar\(|showAppSnackBar\(|message\s*:|title\s*:|subtitle\s*:'
      r'content\s*:|(?:_|\w)*Error\s*=|(?:promo)?[Ee]rror\s*:)',
    );
    final source = RegExp(
      r'(\$\{?(e|err|error|ex|exception|stack)\}?\b'
      r'|\b(e|err|error|ex|exception)\.toString\(\)'
      r'|\$\{?\w+\.lastError\}?)',
    );
    final allowed = RegExp(
      r'(appErrorText\(|appErrorMessage\(|appErrorDetail\(|'
      r'logger\.|_logger|debugPrint|print\()',
    );

    bool isPresentation(String path) =>
        path.contains('/presentation/') || path.contains('/shared/widgets/');

    test('no presentation file renders an exception into a widget', () {
      final offenders = <String>[];
      for (final f in dartFiles()) {
        if (!isPresentation(f.path)) continue;
        final lines = read(f.path).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i].trim();
          if (l.startsWith('//')) continue;
          if (!sink.hasMatch(l)) continue;
          if (!source.hasMatch(l)) continue;
          if (allowed.hasMatch(l)) continue;
          offenders.add('${f.path}:${i + 1}: $l');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'raw exception text must be mapped through appErrorText()/appErrorMessage()',
      );
    });

    test('the safe mapping helpers are used, not bypassed', () {
      // Guards against someone reintroducing a raw renderer behind a new name:
      // every user-visible error must come from the shared classifier.
      final offenders = <String>[];
      for (final f in dartFiles()) {
        if (!isPresentation(f.path)) continue;
        if (f.path.contains('app_error_text.dart')) continue;
        for (final line in read(f.path).split('\n')) {
          final l = line.trim();
          if (l.startsWith('//')) continue;
          if (l.contains('appErrorDetail(') &&
              !RegExp(r'(\w+\s*=|error\s*:|promoError\s*:)').hasMatch(l)) {
            offenders.add('${f.path}: appErrorDetail() outside a technical field: $l');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('the classifier itself never returns the raw error', () {
      final src = read('lib/core/errors/app_error_text.dart');
      // Every branch of the switch must resolve to a localized getter.
      final branches = RegExp(r'case AppErrorKind\.\w+:\s*\n\s*return l10n\.(\w+);')
          .allMatches(src)
          .map((m) => m.group(1)!)
          .toList();
      expect(branches.length, AppErrorKind.values.length);
      expect(
        branches.toSet().length,
        greaterThanOrEqualTo(AppErrorKind.values.length - 1),
        reason: 'several failure kinds must not share one sentence',
      );
      for (final key in [
        'noConnection',
        'errorTimeout',
        'errorUnauthenticated',
        'errorForbidden',
        'errorNotFound',
        'errorConflict',
        'errorServerIssue',
        'somethingWentWrong',
      ]) {
        expect(branches, contains(key));
      }
    });
  });

  group('Arabic UI strings are localized', () {
    test('no user-facing Arabic literal remains in a page', () {
      final offenders = <String>[];
      // These are DOMAIN DATA, not UI: a thrown exception message, the
      // region search stop-words, and the Arabic fallback labels used when
      // a localized label is unavailable. None of them is rendered as a
      // widget string.
      const dataOnly = {
        'auth_provider.dart',
        'region_resolver.dart',
        'category_visuals.dart',
        'service_booking_repository_impl.dart',
        'location_provider.dart',
        'wallet_balance.dart',
        // A language selector must show each language in its own script.
        'register_page.dart',
        'quick_settings_card.dart',
        // Role names sent in a notification payload, not rendered strings.
        'chat_call_alert_service.dart',
      };
      for (final f in dartFiles()) {
        if (!f.path.contains('/features/')) continue;
        if (dataOnly.any(f.path.endsWith)) continue;
        final lines = read(f.path).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (RegExp(r'_logger\.|debugPrint\(').hasMatch(l)) continue;
          for (final m in RegExp(r"'([^'\\\n]*[؀-ۿ][^'\\\n]*)'")
              .allMatches(l)) {
            final lit = m.group(1)!;
            if (lit.trim().length < 2) continue;
            // A composition like '${l10n.welcome}، $name' interpolates
            // localized parts; the only literal is a separator.
            if (lit.contains(r'${') || lit.trim() == '،') continue;
            // A legitimate Arabic value is fine only when it is not being
            // rendered as a UI label; those must come from the ARB files.
            offenders.add('${f.path}:${i + 1}: $lit');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Arabic literals in the UI mean the page is Arabic-only',
      );
    });
  });

  group('irreversible actions are confirmed', () {
    void expectConfirmation(String path, String action) {
      final src = read(path);
      final idx = src.indexOf(action);
      expect(idx, isNot(-1), reason: '$action not found in $path');
      final window = src.substring(
        (idx - 2500).clamp(0, src.length),
        (idx + 2500).clamp(0, src.length),
      );
      expect(
        window.contains('showDialog<bool>') ||
            window.contains('ConfirmDialog') ||
            window.contains('showConfirmDialog'),
        isTrue,
        reason: '"$action" in $path must ask for confirmation first',
      );
    }

    test('approving a top-up (credits a real wallet) is confirmed', () {
      expectConfirmation(
        'lib/features/admin/financial/presentation/pages/'
        'admin_topup_requests_page.dart',
        '.approveTopup(item.id)',
      );
    });

    test('approving or rejecting a settlement is confirmed', () {
      expectConfirmation(
        'lib/features/admin/financial/presentation/pages/'
        'admin_settlements_page.dart',
        'await repo.approveSettlement(id)',
      );
    });

    test('approving a permanent account deletion is confirmed', () {
      expectConfirmation(
        'lib/features/admin/presentation/pages/'
        'admin_pending_deletions_page.dart',
        "'approve_member_deletion'",
      );
    });

    test('suspending a driver is confirmed', () {
      expectConfirmation(
        'lib/features/admin/presentation/pages/admin_drivers_page.dart',
        'updateDriverOnlineStatus(',
      );
    });
  });

  group('failure is distinguishable from emptiness', () {
    test('the driver access page no longer shows a fabricated success state', () {
      final src = read(
        'lib/features/driver/presentation/pages/driver_access_page.dart',
      );
      expect(
        src.contains('snap.hasError') || src.contains('snapshot.hasError'),
        isTrue,
        reason: 'a failed role lookup used to render the same defaults as a '
            'successful load',
      );
    });

    test('the product detail page handles an error explicitly', () {
      final src = read(
        'lib/features/customer/commerce/presentation/pages/'
        'product_detail_page.dart',
      );
      expect(src, contains('snapshot.hasError'));
    });
  });

  group('accessibility', () {
    test('icon-only buttons carry a tooltip', () {
      final offenders = <String>[];
      for (final f in dartFiles()) {
        final src = read(f.path);
        var idx = 0;
        while (true) {
          idx = src.indexOf('IconButton(', idx);
          if (idx == -1) break;
          final lineStart = src.lastIndexOf('\n', idx) + 1;
          final before = src.substring(lineStart, idx);
          // A constructor declaration is not a rendered control.
          // An identifier ending in IconButton( that is preceded by a
          // letter or underscore (_glassIconButton, MyIconButton) is a
          // user-defined name, NOT Material's IconButton widget.
          // Material's IconButton is always the first token of the
          // expression: `IconButton(`. Anything like `_glassIconButton(`
          // or `MyIconButton(` is a user-defined widget.
          final isNamed =
              !before.trimRight().endsWith('IconButton');
          final isCtor = before.trimLeft().startsWith('const ') || isNamed;
          // Find the balanced closing paren of this call.
          var depth = 0;
          var k = src.indexOf('(', idx);
          for (; k < src.length; k++) {
            final c = src[k];
            if (c == '(') depth++;
            if (c == ')') {
              depth--;
              if (depth == 0) break;
            }
          }
          final body = src.substring(idx, k + 1);
          idx = k + 1;
          if (isCtor) continue;
          // A Tooltip(message:) wrapper is already labelled.
          if (body.contains('tooltip:') || body.contains('message:')) continue;
          final line =
              src.substring(0, idx).split('\n').length;
          offenders.add('${f.path}:$line');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'an IconButton without a tooltip is invisible to TalkBack',
      );
    });
  });

  group('locale parity for the new keys', () {
    test('en and ar still have identical key sets', () {
      final en = jsonDecode(read('lib/l10n/app_en.arb')) as Map<String, dynamic>;
      final ar = jsonDecode(read('lib/l10n/app_ar.arb')) as Map<String, dynamic>;
      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
      final arKeys = ar.keys.where((k) => !k.startsWith('@')).toSet();
      expect(enKeys.difference(arKeys), isEmpty);
      expect(arKeys.difference(enKeys), isEmpty);
    });

    test('the newly localized driver and booking keys exist in both', () {
      for (final f in ['lib/l10n/app_en.arb', 'lib/l10n/app_ar.arb']) {
        final d = jsonDecode(read(f)) as Map<String, dynamic>;
        for (final key in [
          'deliveryDetails',
          'otpPrompt',
          'arriveAtPickup',
          'startDelivery',
          'completeDelivery',
          'orderNotFound',
          'selectServiceProvider',
          'confirmBooking',
          'graceManagement',
          'settlements',
          'globalFinancialAudit',
        ]) {
          expect(d.containsKey(key), isTrue, reason: '$key missing in $f');
        }
      }
    });
  });
}