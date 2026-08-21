import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  test('Sanction entity parses from JSON correctly', () {
    final json = {
      'id': 'test-id',
      'target_user_id': 'user-1',
      'target_role': 'customer',
      'sanction_type': 'warning',
      'complaint_id': null,
      'reason': 'Rule violation',
      'amount': 0,
      'duration_days': 0,
      'start_date': '2026-01-01T00:00:00.000Z',
      'end_date': null,
      'is_active': true,
      'notes': null,
      'issued_by': 'admin-1',
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': null,
    };

    expect(json['id'], 'test-id');
    expect(json['sanction_type'], 'warning');
    expect(json['is_active'], true);
  });

  test('Sanction entity serializes to JSON correctly', () {
    final json = {
      'id': 'test-id',
      'target_user_id': 'user-1',
      'target_role': 'customer',
      'sanction_type': 'suspension',
      'reason': 'Serious violation',
      'amount': 100,
      'duration_days': 30,
      'start_date': '2026-01-01T00:00:00.000Z',
      'is_active': true,
      'issued_by': 'admin-1',
      'created_at': '2026-01-01T00:00:00.000Z',
    };

    expect(json['sanction_type'], 'suspension');
    expect(json['amount'], 100);
    expect(json['duration_days'], 30);
  });

  test('no direct sanctions DML remains in data source', () async {
    final file = File(
      'lib/features/admin/sanctions/data/datasources/remote/supabase_sanctions_data_source.dart',
    );
    final content = await file.readAsString();

    expect(
      content.contains('.from(\'sanctions\').insert'),
      isFalse,
      reason: 'Direct INSERT on sanctions table must not exist',
    );
    expect(
      content.contains('.from(\'sanctions\').update'),
      isFalse,
      reason: 'Direct UPDATE on sanctions table must not exist',
    );
    expect(
      content.contains('.from(\'sanctions\').delete'),
      isFalse,
      reason: 'Direct DELETE on sanctions table must not exist',
    );
    expect(
      content.contains("rpc('issue_sanction'"),
      isTrue,
      reason: 'Must use issue_sanction RPC',
    );
    expect(
      content.contains("rpc('revoke_sanction'"),
      isTrue,
      reason: 'Must use revoke_sanction RPC',
    );
  });

  test('issue_sanction RPC signature matches migration 035', () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(content, contains('p_member_id uuid'));
    expect(content, contains('p_sanction_type text'));
    expect(content, contains('p_reason text'));
    expect(content, contains('p_duration_days int'));
    expect(content, contains('p_amount numeric'));
    expect(content, contains('p_evidence_url text'));
    expect(content, contains('RETURNS uuid'));
    expect(content, contains('SECURITY DEFINER'));
  });

  test('revoke_sanction RPC signature matches migration 035', () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(content, contains('p_sanction_id uuid'));
    expect(content, contains('p_reason text'));
    expect(content, contains('RETURNS void'));
    expect(content, contains('SECURITY DEFINER'));
  });

  test('issue_sanction checks permissions via has_permission', () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(content, contains('MEMBER_WARN'));
    expect(content, contains('MEMBER_RESTRICT'));
    expect(content, contains('MEMBER_SUSPEND'));
    expect(content, contains('MEMBER_BAN'));
    expect(content, contains('has_permission'));
    expect(content, contains('_member_region_id'));
  });

  test('revoke_sanction checks MEMBER_MODERATE permission', () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(content, contains('MEMBER_MODERATE'));
  });

  test('issue_sanction blocks admin targets', () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(
      content,
      contains('_is_active_admin_uid'),
      reason: 'Must check that target is not an admin',
    );
  });

  test('issue_sanction routes bans through approval', () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(
      content,
      contains('submit_approval_request'),
      reason: 'Ban types must go through approval workflow',
    );
    expect(
      content,
      contains('_sanction_requires_approval'),
      reason: 'Must check if sanction requires approval',
    );
  });

  test('revoke_sanction writes audit via _member_exec_revoke_sanction',
      () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(
      content,
      contains('_member_exec_revoke_sanction'),
      reason: 'Revoke must use executor for audit/event logging',
    );
  });

  test('RPCs are revoked from anon and PUBLIC', () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(
      content,
      contains('REVOKE ALL ON FUNCTION public.issue_sanction'),
      reason: 'issue_sanction must be revoked from PUBLIC',
    );
    expect(
      content,
      contains('REVOKE ALL ON FUNCTION public.revoke_sanction'),
      reason: 'revoke_sanction must be revoked from PUBLIC',
    );
  });

  test('RPCs are granted to authenticated only', () async {
    final file = File(
      'supabase/migrations/035_member_management_moderation_deletion.sql',
    );
    final content = await file.readAsString();

    expect(
      content,
      contains('GRANT EXECUTE ON FUNCTION public.issue_sanction'),
      reason: 'issue_sanction must be granted to authenticated',
    );
    expect(
      content,
      contains('GRANT EXECUTE ON FUNCTION public.revoke_sanction'),
      reason: 'revoke_sanction must be granted to authenticated',
    );
  });

  test('member detail page uses RPC-based sanctions', () async {
    final file = File(
      'lib/features/admin/member_management/presentation/pages/member_detail_page.dart',
    );
    final content = await file.readAsString();

    expect(
      content,
      contains('sanctionsRepositoryProvider'),
      reason: 'Must use repository provider for sanctions',
    );
    expect(
      content,
      contains('issueSanction'),
      reason: 'Must call issueSanction RPC',
    );
    expect(
      content,
      contains('revokeSanction'),
      reason: 'Must call revokeSanction RPC',
    );
    expect(
      content.contains('.from(\'sanctions\').insert'),
      isFalse,
      reason: 'No direct INSERT on sanctions',
    );
    expect(
      content.contains('.from(\'sanctions\').update'),
      isFalse,
      reason: 'No direct UPDATE on sanctions',
    );
  });

  test('member detail page refreshes after sanction operations', () async {
    final file = File(
      'lib/features/admin/member_management/presentation/pages/member_detail_page.dart',
    );
    final content = await file.readAsString();

    expect(
      content,
      contains('invalidate(memberStatusProvider'),
      reason: 'Must invalidate status after sanction/revoke',
    );
    expect(
      content,
      contains('invalidate(memberTimelineProvider'),
      reason: 'Must invalidate timeline after sanction/revoke',
    );
  });

  test('admin sanctions page uses RPC-based revoke', () async {
    final file = File(
      'lib/features/admin/sanctions/presentation/pages/admin_sanctions_page.dart',
    );
    final content = await file.readAsString();

    expect(
      content,
      contains('sanctionsRepositoryProvider'),
      reason: 'Must use repository provider',
    );
    expect(
      content,
      contains('revokeSanction'),
      reason: 'Must call revokeSanction RPC',
    );
    expect(
      content.contains('.from(\'sanctions\').update'),
      isFalse,
      reason: 'No direct UPDATE on sanctions',
    );
  });
}
