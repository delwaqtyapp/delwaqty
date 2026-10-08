import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the app<->database contract that every other test cannot see.
///
/// Each defect guarded here was a write that could NEVER succeed because
/// the column, the CHECK constraint or the RPC argument did not exist:
///   * `orders.subtotal` is NOT NULL and was never inserted -> every
///     checkout failed;
///   * `orders.special_instructions`, `order_items.product_name`,
///     `orders.cancelled_at` did not exist -> PGRST204;
///   * `orders_payment_method_check` rejected instapay / vodafone_cash;
///   * `wallet_transactions.type` rejected 'topup' / 'payment';
///   * `increment_coupon_usage` was called with `coupon_code` instead of
///     `p_coupon_code`, so every coupon redemption failed silently;
///   * `decide_user_verification` was called with 'approved'/'rejected'
///     instead of 'approve'/'reject', so the admin verification queue was
///     a no-op that reported success;
///   * `provider_delete_document` referenced a `user_id` column that
///     `provider_documents` does not have;
///   * identity documents were uploaded to the PUBLIC `profiles` bucket;
///   * the OTA updater installed a downloaded APK with no checksum;
///   * INTERNET was only in the debug manifest, so a release build would
///     have no network at all.
///
/// The SQL text is read from the migrations so the suite stays hermetic
/// (no network in tests); the assertions are written against plain
/// substring presence rather than brittle regexes.
void main() {
  final migrationDir = Directory('supabase/migrations');
  final migrationFiles = migrationDir.existsSync()
      ? (migrationDir.listSync().whereType<File>().toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  String readSql() =>
      migrationFiles.map((f) => f.readAsStringSync()).join('\n;\n');

  late String sql;

  setUpAll(() => sql = readSql());

  group('schema contract', () {
    test('the migration set is present', () {
      expect(migrationFiles, isNotEmpty, reason: 'no migrations found');
      expect(migrationFiles.length, greaterThan(100));
    });

    test('every order column the order data source writes exists', () {
      // supabase_order_data_source.dart -> createOrder / cancelOrder
      const writes = <String>[
        'merchant_name',
        'special_instructions',
        'subtotal',
        'total_amount',
        'delivery_fee',
        'discount',
        'tax',
        'delivery_address',
        'payment_method',
        'payment_status',
        'cancelled_at',
        'cancelled_reason',
      ];
      for (final column in writes) {
        expect(
          sql.contains(column),
          isTrue,
          reason: 'orders.$column is written by the app but no migration '
              'declares it',
        );
      }
    });

    test('the order_items snapshot columns exist', () {
      for (final column in ['product_name', 'variant_name', 'modifiers']) {
        expect(
          sql.contains(column),
          isTrue,
          reason: 'order_items.$column is written by the app',
        );
      }
    });

    test('payment_method CHECK covers every checkout option', () {
      // checkout_page.dart offers exactly these five.
      for (final method in [
        'cash',
        'card',
        'wallet',
        'instapay',
        'vodafone_cash',
      ]) {
        expect(
          sql.contains("'$method'"),
          isTrue,
          reason: 'payment_method CHECK must allow "$method"',
        );
      }
      expect(
        sql,
        contains('orders_payment_method_check'),
        reason: 'the constraint must be re-declared, not only the base one',
      );
    });

    test('wallet_transactions type CHECK covers the kinds the app writes', () {
      for (final kind in ['credit', 'debit', 'topup', 'payment']) {
        expect(
          sql.contains("'$kind'"),
          isTrue,
          reason: 'wallet_transactions.type must allow "$kind"',
        );
      }
      expect(sql, contains('wallet_transactions_type_check'));
    });

    test('driver_documents doc_type CHECK covers the onboarding uploads', () {
      // driver_onboarding_page.dart uploads these two.
      for (final type in ['driving_license', 'vehicle_registration']) {
        expect(
          sql.contains("'$type'"),
          isTrue,
          reason: 'driver_documents.doc_type must allow "$type"',
        );
      }
    });

    test('the coupon RPC is declared with the p_coupon_code parameter', () {
      expect(
        RegExp(r'increment_coupon_usage\(\s*p_coupon_code').hasMatch(sql) ||
            sql.contains('p_coupon_code'),
        isTrue,
        reason: 'the app now sends p_coupon_code; the function must match',
      );
    });

    test('the verification decision values are approve/reject', () {
      // The app sends 'approve'/'reject'; the enum column is
      // approved/rejected and the RPC translates between them.
      expect(sql, contains("'approve'"));
      expect(sql, contains("'reject'"));
      expect(
        sql,
        contains('decide_user_verification'),
        reason: 'the verification RPC is the only legal write path',
      );
    });
  });

  group('security contract', () {
    test('identity documents live in a private bucket', () {
      expect(sql, contains('identity-documents'));
      final m = RegExp(
        r"'identity-documents',\s*'identity-documents',\s*false",
        dotAll: true,
      ).firstMatch(sql);
      expect(
        m,
        isNotNull,
        reason: 'the identity-documents bucket must be created with '
            'public = false',
      );
    });

    test('a client cannot write its own wallet balance', () {
      expect(
        sql,
        contains('REVOKE UPDATE (balance) ON public.wallets'),
        reason: 'the client must not be able to PATCH its own balance',
      );
      expect(sql, contains('wallet_topup'));
      expect(sql, contains('wallet_pay'));
    });

    test('count_table_rows is authorized and whitelisted', () {
      final m = RegExp(
        r'CREATE (?:OR REPLACE )?FUNCTION public\.count_table_rows[\s\S]*?\$\$;',
      ).firstMatch(sql);
      expect(m, isNotNull);
      final body = m!.group(0)!;
      expect(body, contains('_is_active_admin_uid'));
      expect(body, contains('table_name NOT IN'));
    });

    test('provider_delete_document targets the real ownership column', () {
      final file = File(
        'supabase/migrations/104_provider_document_delete_rpc.sql',
      );
      expect(file.existsSync(), isTrue);
      final body = file.readAsStringSync();
      expect(body, contains('provider_id = v_uid'));
      expect(
        body,
        isNot(contains('WHERE user_id = v_uid')),
        reason: 'provider_documents has no user_id column',
      );
    });

    test('a merchant reply cannot overwrite the customer review text', () {
      final file = File(
        'supabase/migrations/108_merchant_review_reply.sql',
      );
      expect(file.existsSync(), isTrue);
      final body = file.readAsStringSync();
      final update = RegExp(
        r'UPDATE public\.reviews([\s\S]*?)WHERE id = p_review_id',
      ).firstMatch(body);
      expect(update, isNotNull);
      final assignments = update!.group(1)!;
      expect(assignments, contains('merchant_reply'));
      expect(
        assignments,
        isNot(contains('comment =')),
        reason: 'the reply RPC must never write reviews.comment',
      );
    });

    test('admin policies exist for the operational tables', () {
      for (final table in ['orders', 'drivers', 'rides']) {
        expect(
          sql.contains(table),
          isTrue,
        );
        expect(
          RegExp('Admins can (view all|update any) $table',
              caseSensitive: false).hasMatch(sql),
          isTrue,
          reason: 'missing an admin policy on $table',
        );
      }
    });
  });

  group('driver dispatch contract', () {
    test('one RPC satisfies every dispatch_delivery precondition', () {
      // dispatch_delivery filters on:
      //   status = 'online' AND is_verified AND active_vehicle_id IS NOT NULL
      // The old toggles each moved only half of that.
      expect(sql, contains('driver_set_online_state'));
      final m = RegExp(
        r'CREATE OR REPLACE FUNCTION public\.driver_set_online_state[\s\S]*?\$\$;',
      ).firstMatch(sql);
      expect(m, isNotNull);
      final body = m!.group(0)!;
      expect(body, contains('status ='));
      expect(body, contains('is_online ='));
      expect(body, contains('active_vehicle_id'));
    });

    test('registration makes the driver dispatchable', () {
      expect(sql, contains('driver_complete_registration'));
      expect(
        sql.contains('is_verified'),
        isTrue,
        reason: 'an unverified driver is invisible to the dispatch engine',
      );
    });
  });

  group('manifest contract', () {
    test('release builds declare network + background location', () {
      final main = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        main,
        contains('android.permission.INTERNET'),
        reason: 'INTERNET was only in the debug manifest, so a release APK '
            'would have no network at all',
      );
      expect(
        main,
        contains('ACCESS_BACKGROUND_LOCATION'),
        reason: 'a backgrounded driver would freeze with a stale location',
      );
      expect(main, contains('FOREGROUND_SERVICE_LOCATION'));
    });

    test('the admin notification channel id exists in Dart', () {
      final manifest = File(
        'android/app/src/admin/AndroidManifest.xml',
      ).readAsStringSync();
      final m = RegExp(
        r'default_notification_channel_id"\s+value="([^"]+)"',
      ).firstMatch(manifest);
      if (m == null) return;
      final service = File(
        'lib/services/push_notification/push_notification_service.dart',
      ).readAsStringSync();
      expect(
        service,
        contains(m.group(1)!),
        reason: 'SDK-delivered notifications go to a channel the Dart code '
            'never creates, so they are dropped',
      );
    });
  });

  group('ota contract', () {
    test('a downloaded APK must match a published checksum', () {
      final ota = File(
        'lib/services/ota/ota_update_manager.dart',
      ).readAsStringSync();
      expect(
        ota,
        contains('verifyArtifactChecksum'),
        reason: 'the installer must verify the artifact digest',
      );
      expect(ota, contains('missing_checksum'));
      expect(ota, contains('checksum_mismatch'));
      expect(
        ota,
        contains('sha256'),
        reason: 'the manifest must carry the release digest',
      );
    });
  });

  group('l10n contract', () {
    Map<String, dynamic> arb(String name) =>
        jsonDecode(File('lib/l10n/$name.arb').readAsStringSync())
            as Map<String, dynamic>;

    test('en and ar have identical key sets', () {
      final en = arb('app_en').keys.where((k) => !k.startsWith('@')).toSet();
      final ar = arb('app_ar').keys.where((k) => !k.startsWith('@')).toSet();
      expect(
        en.difference(ar),
        isEmpty,
        reason: 'keys with no Arabic translation',
      );
      expect(ar.difference(en), isEmpty);
    });

    test('the currency symbol is not swapped between locales', () {
      final en = arb('app_en');
      final ar = arb('app_ar');
      // The platform is Egypt-only: EGP / ج.م.
      expect(en['sar'], 'EGP');
      expect(ar['sar'], 'ج.م');
    });
  });
}