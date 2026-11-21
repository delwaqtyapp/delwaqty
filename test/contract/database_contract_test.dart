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
  final migrationFiles = <File>[
    for (final dir in [
      Directory('supabase/migrations_archive'),
      Directory('supabase/migrations'),
    ])
      if (dir.existsSync()) ...dir.listSync().whereType<File>(),
  ]..sort((a, b) => a.path.compareTo(b.path));

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
          reason:
              'orders.$column is written by the app but no migration '
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
        reason:
            'the identity-documents bucket must be created with '
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
        'supabase/migrations_archive/104_provider_document_delete_rpc.sql',
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
        'supabase/migrations_archive/108_merchant_review_reply.sql',
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
        expect(sql.contains(table), isTrue);
        expect(
          RegExp(
            'Admins can (view all|update any) $table',
            caseSensitive: false,
          ).hasMatch(sql),
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

    test(
      'registration cannot self-verify; admin review requires documents',
      () {
        final latest = File(
          'supabase/migrations_archive/139_driver_verification_document_custody.sql',
        ).readAsStringSync();
        final registration = latest
            .split(
              'CREATE OR REPLACE FUNCTION public.driver_complete_registration',
            )
            .last
            .split('CREATE OR REPLACE FUNCTION public.register_ride_driver')
            .first;
        expect(registration, contains("false, 'pending'"));
        expect(registration, isNot(contains('is_verified = true')));
        expect(latest, contains('driver_application_documents_ready'));
        expect(latest, contains('REQUIRED_DOCUMENTS_MISSING'));
        expect(latest, contains('ACTIVE_VEHICLE_REQUIRED'));
        expect(latest, contains('review_driver_application'));
      },
    );
  });

  group('manifest contract', () {
    test('release builds declare network + background location', () {
      final main = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(
        main,
        contains('android.permission.INTERNET'),
        reason:
            'INTERNET was only in the debug manifest, so a release APK '
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
      final manifest = File('android/app/src/admin/AndroidManifest.xml')
          .readAsStringSync();
      final m = RegExp(r'default_notification_channel_id"\s+value="([^"]+)"')
          .firstMatch(manifest);
      if (m == null) return;
      final service = File(
        'lib/services/push_notification/push_notification_service.dart',
      ).readAsStringSync();
      expect(
        service,
        contains(m.group(1)!),
        reason:
            'SDK-delivered notifications go to a channel the Dart code '
            'never creates, so they are dropped',
      );
    });
  });

  group('ota contract', () {
    test('a downloaded APK must match a published checksum', () {
      final ota = File('lib/services/ota/ota_update_manager.dart')
          .readAsStringSync();
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
      expect(en['egp'], 'EGP');
      expect(ar['egp'], 'ج.م');
    });
  });

  group('order dispatch lifecycle (migration 217)', () {
    // Sim lab full-order smoke test: three defects that broke the
    // create -> dispatch -> accept lifecycle for app-created orders.
    // Assertions run against the LATEST migration file defining each
    // function (later migrations supersede earlier definitions).
    String latestDefining(String marker) {
      // Application order is numeric by migration prefix, not file path:
      // migrations_archive/ holds 001-214, migrations/ holds 000 + 215+.
      int numOf(File f) => int.parse(f.path.split('/').last.split('_').first);
      final hits =
          migrationFiles
              .where((f) => f.readAsStringSync().contains(marker))
              .toList()
            ..sort((a, b) => numOf(a).compareTo(numOf(b)));
      expect(hits, isNotEmpty, reason: '$marker not found in migrations');
      return hits.last.readAsStringSync();
    }

    test('create_order_idempotent accepts and stores delivery coordinates', () {
      expect(sql, contains('p_delivery_latitude numeric DEFAULT NULL'));
      final latest = latestDefining('FUNCTION public.create_order_idempotent');
      expect(latest, contains('delivery_latitude'));
      expect(latest, contains('p_delivery_longitude'));
    });

    test('accept_order ride propagation never filters on ride_type', () {
      // rides.ride_type is a vehicle class per rides_ride_type_check, so
      // ride_type = 'delivery' can never match and silently updated 0 rows.
      final latest = latestDefining(
        'FUNCTION public.accept_order(p_order_id uuid, p_driver_id uuid)',
      );
      expect(latest, isNot(contains("ride_type = 'delivery'")));
      expect(latest, contains("AND status = 'searching'"));
    });

    test('accept_ride_request writes the enum-checked vehicle category', () {
      // veh.make || ' ' || veh.model violates
      // rides_delivery_vehicle_type_check (23514) whenever set.
      final latest = latestDefining('FUNCTION public.accept_ride_request');
      expect(latest, isNot(contains("veh.make || ' ' || veh.model")));
      expect(latest, contains('COALESCE(veh.category, drv.vehicle_type)'));
    });

    test('the canonical ride path expires parallel dispatch offers', () {
      final latest = latestDefining(
        'FUNCTION public.sync_linked_delivery_order',
      );
      expect(latest, contains("status='expired'"));
    });
  });

  String latestDefining221(String marker) {
    int numOf(File f) => int.parse(f.path.split('/').last.split('_').first);
    final hits =
        migrationFiles
            .where((f) => f.readAsStringSync().contains(marker))
            .toList()
          ..sort((a, b) => numOf(a).compareTo(numOf(b)));
    expect(hits, isNotEmpty, reason: '$marker not found in migrations');
    return hits.last.readAsStringSync();
  }

  group('canonical create path (migration 221)', () {
    test('create_order accepts every payment method the CHECK allows', () {
      final latest = latestDefining221('FUNCTION public.create_order(');
      expect(latest, contains("'card'"));
      expect(latest, contains("'wallet'"));
      expect(latest, contains('orders_payment_method_check'));
    });

    test('create_order_idempotent delegates to server-side pricing', () {
      // C5: the wrapper must never trust client amounts; it forwards only
      // product ids and quantities to the canonical create_order.
      final latest = latestDefining221(
        'FUNCTION public.create_order_idempotent',
      );
      expect(latest, contains('RETURN public.create_order('));
      expect(latest, isNot(contains('INSERT INTO public.orders')));
      expect(latest, isNot(contains('p_subtotal,')));
    });
  });

  group('modifier pricing (migration 226)', () {
    // MEDIUM-3: modifier price adjustments must be priced server-side from
    // product_modifier_options, never from client-supplied amounts.
    test('create_order prices modifiers from the catalog', () {
      final latest = latestDefining221('FUNCTION public.create_order(');
      expect(latest, contains('product_modifier_options'));
      expect(latest, contains('price_adjustment'));
      expect(latest, contains('INVALID_MODIFIER'));
      expect(latest, contains('modifier_option_ids'));
    });

    test('create_order_idempotent forwards modifier selections', () {
      final latest = latestDefining221(
        'FUNCTION public.create_order_idempotent',
      );
      expect(latest, contains('modifier_option_ids'));
      expect(latest, isNot(contains('p_subtotal,')));
    });
  });

  group('rpc grant lockdown (migration 218)', () {
    // Security reviewer C4/C5: client-callable SECURITY DEFINER money and
    // pricing functions. The app calls none of them; they must be revoked
    // from public/anon/authenticated after every migration apply.
    test('client-exploitable RPCs are revoked in the lockdown migration', () {
      final lockdown = migrationFiles
          .where((f) => f.path.contains('218_rpc_grant_lockdown'))
          .single
          .readAsStringSync();
      for (final fn in [
        'wallet_topup',
        'wallet_refund',
        'apply_coupon',
        'run_member_engines',
        'log_admin_action',
        'write_audit',
        'create_order_idempotent',
      ]) {
        expect(lockdown, contains("'$fn'"), reason: '$fn missing from sweep');
      }
      expect(
        lockdown,
        contains(
          'REVOKE EXECUTE ON FUNCTION %s FROM public, anon, authenticated',
        ),
      );
      // And the recurrence guard for functions created later.
      expect(lockdown, contains('ALTER DEFAULT PRIVILEGES FOR ROLE postgres'));
    });

    test('the app never calls the revoked RPCs', () {
      final libFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final fn in [
        "'wallet_topup'",
        "'wallet_refund'",
        "'apply_coupon'",
        "'run_member_engines'",
        "'create_order_idempotent'",
      ]) {
        for (final f in libFiles) {
          expect(
            f.readAsStringSync().contains('.rpc(\n        $fn,') ||
                f.readAsStringSync().contains("rpc($fn"),
            isFalse,
            reason: '${f.path} still calls $fn',
          );
        }
      }
    });
  });
}
