import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the capabilities closed in ROUND 89.
///
/// Each of these was a table + an RLS policy + a repository method with NO
/// page and NO writer, so the capability was unreachable: a merchant could
/// not restock, could not edit their storefront or hours, and the admin had
/// no emergency console, no audit view and could not claim a complaint.
void main() {
  final migrations = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final sql = migrations.map((f) => f.readAsStringSync()).join('\n---\n');

  String read(String path) => File(path).readAsStringSync();

  group('merchant capability migrations', () {
    test('the merchant id is resolved server-side, never auth.uid()', () {
      expect(sql, contains('resolve_my_merchant'));
      final module = read(
        'lib/features/provider/merchant/presentation/providers/'
        'merchant_providers.dart',
      );
      expect(
        module,
        contains('resolve_my_merchant'),
        reason: 'passing auth.uid() as merchant_id filters on a value that '
            'can never match a merchants.id',
      );
      expect(
        module,
        isNot(contains("authState.user.id : ''")),
        reason: 'the provider must not fall back to the auth uid',
      );
    });

    test('a storefront writer exists', () {
      expect(sql, contains('update_my_storefront'));
      final page = read(
        'lib/features/provider/merchant/presentation/pages/'
        'merchant_storefront_page.dart',
      );
      expect(page, contains('update_my_storefront'));
      // Every storefront field must be editable, not just the name.
      for (final field in [
        'p_name',
        'p_description',
        'p_logo_url',
        'p_phone',
        'p_address',
        'p_delivery_fee',
        'p_min_order',
      ]) {
        expect(sql, contains(field), reason: '$field must be settable');
      }
    });

    test('working hours can be written, not only read', () {
      expect(sql, contains('provider_set_working_hours'));
      final page = read(
        'lib/features/provider/merchant/presentation/pages/'
        'merchant_storefront_page.dart',
      );
      expect(page, contains('provider_set_working_hours'));
      // Invalid input must be rejected server-side.
      final rpc = RegExp(
        r'CREATE OR REPLACE FUNCTION public\.provider_set_working_hours[\s\S]*?\$\$;',
      ).firstMatch(sql)?.group(0) ?? '';
      expect(rpc, contains('Invalid day of week'));
      expect(rpc, contains('Invalid time format'));
      expect(rpc, contains('must be after opening time'));
    });
  });

  group('admin capability pages', () {
    test('the SOS console exists and is routed', () {
      final page = File(
        'lib/features/admin/presentation/pages/admin_emergency_page.dart',
      );
      expect(page.existsSync(), isTrue);
      final body = page.readAsStringSync();
      expect(body, contains('adminSosAlertsProvider'));
      expect(body, contains('resolveSosAlert'));

      final module = read('lib/features/admin/admin_module.dart');
      expect(
        module,
        contains("path: 'emergency'"),
        reason: 'four entry points linked to /admin/emergency',
      );
    });

    test('the audit log page exists and is reachable', () {
      final page = File(
        'lib/features/admin/presentation/pages/admin_audit_log_page.dart',
      );
      expect(page.existsSync(), isTrue);
      expect(page.readAsStringSync(), contains('recentActivityProvider'));

      final module = read('lib/features/admin/admin_module.dart');
      expect(module, contains("path: 'audit-log'"));
      final shell = read('lib/features/admin/admin_shell.dart');
      expect(
        shell,
        contains('/admin/audit-log'),
        reason: 'the audit view must be reachable from the console nav',
      );
    });

    test('complaints can be claimed by an admin', () {
      final page = read(
        'lib/features/_shared/complaints/presentation/pages/'
        'admin_complaints_page.dart',
      );
      expect(page, contains('assignComplaintProvider'));
      expect(
        page,
        contains('addAdminNote'),
      );
    });

    test('service performance renders real data, not placeholders', () {
      final page = read(
        'lib/features/admin/presentation/pages/service_performance_page.dart',
      );
      expect(
        page,
        contains('servicePerformanceProvider'),
        reason: 'the RPC and the provider existed but the page showed '
            '"no data yet" placeholders',
      );
      expect(page, isNot(contains('adminServicePerformancePending\n')));
    });
  });

  group('module registration', () {
    test('the new merchant routes are registered', () {
      final module = read('lib/features/provider/merchant/merchant_module.dart');
      expect(module, contains("path: 'inventory'"));
      expect(module, contains("path: 'storefront'"));
    });

    test('the merchant dashboard links to both new surfaces', () {
      final page = read(
        'lib/features/provider/merchant/presentation/pages/'
        'merchant_dashboard_page.dart',
      );
      expect(page, contains('/merchant-dashboard/inventory'));
      expect(page, contains('/merchant-dashboard/storefront'));
    });
  });

  group('firebase configuration', () {
    test('no flavor ships a placeholder app id', () {
      final raw = read('android/app/google-services.json');
      expect(
        raw,
        isNot(contains('admin_placeholder')),
        reason: 'a placeholder mobilesdk_app_id makes every Firebase call '
            'return 404 (Crashlytics, Messaging, Installations)',
      );
    });

    test('every registered package has a mobilesdk_app_id', () {
      final raw = read('android/app/google-services.json');
      // Crude but dependency-free: each package_name must be followed by a
      // real app id, never the literal "placeholder".
      expect(raw.contains('mobilesdk_app_id'), isTrue);
      expect(raw, isNot(contains(':android:placeholder')));
    });
  });
}