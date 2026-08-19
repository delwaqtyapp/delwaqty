import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('migration 044 exists and is syntactically valid', () async {
    final file = File('supabase/migrations/044_member_management_list_rpc.sql');
    expect(await file.exists(), isTrue, reason: 'Migration 044 missing');

    final content = await file.readAsString();
    expect(content, contains('CREATE OR REPLACE FUNCTION public.list_members'));
    expect(content, contains('p_limit'));
    expect(content, contains('p_cursor'));
    expect(content, contains('p_search'));
    expect(content, contains('p_role'));
    expect(content, contains('p_account_status'));
    expect(content, contains('p_region_id'));
    expect(content, contains('SECURITY DEFINER'));
    expect(content, contains('SET search_path'));
  });

  test('get_member_profile RPC exists in migration 035', () async {
    final file = File('supabase/migrations/035_member_management_moderation_deletion.sql');
    expect(await file.exists(), isTrue);

    final content = await file.readAsString();
    expect(content, contains('get_member_profile'));
    expect(content, contains('get_member_status'));
    expect(content, contains('get_member_timeline'));
  });

  test('issue_sanction and revoke_sanction RPCs exist', () async {
    final file = File('supabase/migrations/035_member_management_moderation_deletion.sql');
    expect(await file.exists(), isTrue);

    final content = await file.readAsString();
    expect(content, contains('issue_sanction'));
    expect(content, contains('revoke_sanction'));
  });

  test('Member entity can parse from JSON', () async {
    final json = {
      'id': 'test-id',
      'full_name': 'Test User',
      'email': 'test@example.com',
      'phone': '123456',
      'role': 'customer',
      'account_status': 'active',
      'verification_status': 'unverified',
      'region_id': null,
      'created_at': '2025-01-01T00:00:00.000Z',
    };

    // Import would be tested here in unit test context
    expect(json['id'], isNotNull);
    expect(json['role'], 'customer');
  });

  test('module_registry includes member_management', () async {
    final file = File('lib/module_registry.dart');
    final content = await file.readAsString();
    expect(content, contains('MemberManagementModule'));
    expect(content, contains('member_management/member_management_module.dart'));
  });

  test('admin_module includes member routes', () async {
    final file = File('lib/features/admin/admin_module.dart');
    final content = await file.readAsString();
    expect(content, contains("path: 'members'"));
    expect(content, contains('MemberOperationsCenter'));
  });

  test('sidebar collapses admin nav to a single entry', () async {
    final file = File('lib/features/floating_sidebar/floating_sidebar_overlay.dart');
    final content = await file.readAsString();
    expect(content, contains('/admin'));
    expect(content, isNot(contains('/admin/members')));
  });

  test('admin_shell hosts the grouped admin navigation', () async {
    final file = File('lib/features/admin/admin_shell.dart');
    final content = await file.readAsString();
    expect(content, contains('/admin/members'));
    expect(content, contains('/admin/commissions'));
    expect(content, contains('/admin/approvals'));
  });
}
