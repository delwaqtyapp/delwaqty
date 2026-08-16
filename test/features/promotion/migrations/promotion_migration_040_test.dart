import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates migration 040 (targeting + audience + approval + lifecycle +
/// media/storage) against the SQL file as the single source of truth.
/// The file must stay idempotent/additive and never hand DELETE rights or
/// client write grants on approval_requests / campaigns beyond the contract.
void main() {
  final migration = File('supabase/migrations/040_promotion_targeting_media_approval.sql')
      .readAsStringSync();

  group('040 — tables, constraints, RLS', () {
    test('creates the 3 new tables with RLS enabled', () {
      for (final table in ['campaign_targets', 'campaign_media', 'approval_requests']) {
        expect(migration, contains('CREATE TABLE IF NOT EXISTS public.$table'));
        expect(migration, contains('ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY'));
      }
    });

    test('campaign_targets is a normalized many-to-many with NULL = national', () {
      expect(migration, contains('REFERENCES public.regions(id) ON DELETE CASCADE'));
      expect(migration, contains('UNIQUE (campaign_id, region_id)'));
      expect(
        migration,
        contains(
          'CREATE UNIQUE INDEX IF NOT EXISTS campaign_targets_national_unique',
        ),
      );
      expect(migration, contains('ON public.campaign_targets (campaign_id) WHERE region_id IS NULL'));
    });

    test('approval_requests matches the 2.3 §19 contract verbatim', () {
      expect(migration, contains('request_type     text NOT NULL'));
      expect(migration, contains('entity_type      text NOT NULL'));
      expect(migration, contains('entity_id        uuid,'));
      expect(migration, contains('payload          jsonb,'));
      expect(migration, contains('requested_by     uuid NOT NULL REFERENCES public.users(id)'));
      expect(migration, contains('required_approver uuid REFERENCES public.users(id)'));
      expect(
        migration,
        contains("CHECK (state IN ('pending','approved','rejected','cancelled'))"),
      );
      expect(migration, contains('decided_by       uuid REFERENCES public.users(id)'));
      expect(migration, contains('decided_at       timestamptz'));
      expect(migration, contains('created_at       timestamptz NOT NULL DEFAULT now()'));
      expect(
        migration,
        contains(
          'CREATE UNIQUE INDEX IF NOT EXISTS approval_requests_pending_unique',
        ),
      );
      expect(
        migration,
        contains(
          "ON public.approval_requests (request_type, entity_id) WHERE state = 'pending'",
        ),
      );
    });

    test('approval_requests RLS: admin all + requester read, no client write grant', () {
      expect(migration, contains('"approval_requests admin all"'));
      expect(migration, contains('"approval_requests requester select"'));
      expect(migration, contains('GRANT SELECT ON public.approval_requests TO authenticated'));
    });
  });

  group('040 — lifecycle RPCs (minimum secure API)', () {
    const rpcs = {
      'campaign_submit': '(p_campaign_id uuid, p_reason text)',
      'decide_approval_request': '(p_request_id uuid, p_decision text, p_reason text)',
      'campaign_publish': '(p_campaign_id uuid)',
      'campaign_pause': '(p_campaign_id uuid, p_reason text)',
      'campaign_resume': '(p_campaign_id uuid)',
      'campaign_archive': '(p_campaign_id uuid, p_reason text)',
      'campaign_cancel': '(p_campaign_id uuid, p_reason text)',
      'campaign_purge_media': '(p_campaign_id uuid)',
    };

    test('declares all 8 lifecycle RPCs with the approved signatures', () {
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_submit(p_campaign_id uuid, p_reason text)'));
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_publish(p_campaign_id uuid)'));
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_pause(p_campaign_id uuid, p_reason text)'));
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_resume(p_campaign_id uuid)'));
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_archive(p_campaign_id uuid, p_reason text)'));
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_cancel(p_campaign_id uuid, p_reason text)'));
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_purge_media(p_campaign_id uuid)'));
      expect(
        migration,
        contains('CREATE OR REPLACE FUNCTION public.decide_approval_request('),
      );
      expect(migration, contains('  p_request_id uuid,'));
      expect(migration, contains('  p_decision text,'));
      expect(migration, contains('  p_reason text'));
    });

    test('every RPC is SECURITY DEFINER with a pinned search_path', () {
      final blockCount =
          RegExp('SECURITY DEFINER\\nSET search_path = public, pg_temp').allMatches(migration).length;
      expect(blockCount, greaterThanOrEqualTo(rpcs.length));
    });

    test('ACL hygiene: PUBLIC/anon EXECUTE revoked, authenticated+service_role granted', () {
      const aclSignatures = {
        'campaign_submit': '(uuid, text)',
        'decide_approval_request': '(uuid, text, text)',
        'campaign_publish': '(uuid)',
        'campaign_pause': '(uuid, text)',
        'campaign_resume': '(uuid)',
        'campaign_archive': '(uuid, text)',
        'campaign_cancel': '(uuid, text)',
        'campaign_purge_media': '(uuid)',
      };
      for (final entry in aclSignatures.entries) {
        expect(migration, contains('REVOKE ALL ON FUNCTION public.${entry.key}${entry.value} FROM PUBLIC'));
        expect(migration, contains('REVOKE ALL ON FUNCTION public.${entry.key}${entry.value} FROM anon'));
        expect(
          migration,
          contains(
            'GRANT EXECUTE ON FUNCTION public.${entry.key}${entry.value}\n'
            '  TO authenticated, service_role',
          ),
          reason: entry.key,
        );
      }
    });

    test('decide_approval_request blocks self-approval, unsolicited types, empty reason', () {
      expect(migration, contains("RAISE EXCEPTION 'Cannot decide your own request'"));
      expect(migration, contains("RAISE EXCEPTION 'Unsupported request type'"));
      expect(migration, contains("RAISE EXCEPTION 'Rejection requires a reason'"));
      expect(migration, contains("RAISE EXCEPTION 'Invalid decision'"));
    });

    test('campaign_submit validates targets, benefit and audience before creating the request', () {
      expect(migration, contains("RAISE EXCEPTION 'Campaign must have at least one targeting region'"));
      expect(migration, contains("RAISE EXCEPTION 'Invalid campaign benefit'"));
      expect(migration, contains("RAISE EXCEPTION 'Invalid campaign audience roles'"));
      expect(migration, contains('request_type, entity_type, entity_id, payload, requested_by, required_approver'));
      expect(migration, contains("'campaign_approve', 'campaign', p_campaign_id,"));
    });

    test('every decision records a review + notification with idempotency key', () {
      expect(migration, contains('INSERT INTO public.campaign_reviews'));
      expect(migration, contains('idempotency_key'));
      expect(migration, contains("'campaign-approve-' || p_request_id::text"));
      expect(migration, contains("'campaign-reject-' || p_request_id::text"));
    });
  });

  group('040 — audience + targeting authorization', () {
    test('scope helpers enforce owner/global vs assigned+descendants', () {
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_can_target_region'));
      expect(migration, contains('CREATE OR REPLACE FUNCTION public.campaign_targets_authorized'));
      expect(migration, contains('public.is_admin_for_region(p_region_id)'));
      expect(migration, contains('AND NOT public.campaign_can_target_region(t.region_id)'));
    });

    test('client inserts are RLS-gated per region; targets have no UPDATE policy', () {
      expect(migration, contains('"campaign_targets admin insert"'));
      expect(migration, contains('public.campaign_can_target_region(region_id)'));
      expect(migration, contains('"campaign_targets admin delete"'));
      expect(migration, contains('FOR INSERT WITH CHECK (public.is_admin())'));
    });
  });

  group('040 — media + storage', () {
    test('campaign-media bucket: private, 5 MB, png/jpeg/webp, idempotent', () {
      expect(migration, contains('INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)'));
      expect(migration, contains("('campaign-media', 'campaign-media', false, 5242880,"));
      expect(migration, contains("ARRAY['image/png','image/jpeg','image/webp'])"));
      expect(migration, contains('ON CONFLICT (id) DO NOTHING'));
    });

    test('4 storage policies: published read + admin upload/update/delete, TO authenticated', () {
      for (final name in ['published read', 'admin upload', 'admin update', 'admin delete']) {
        expect(migration, contains('"campaign media $name"'));
      }
      expect(migration, contains('FOR SELECT USING ('));
      expect(migration, contains('public.campaign_published_for_storage(name)'));
      expect(migration, contains('FOR INSERT TO authenticated'));
      expect(migration, contains('public.campaign_scoped_for_storage(name)'));
    });

    test('path helper derives campaign id from storage.foldername()[2]', () {
      expect(migration, contains('public.campaign_id_from_storage_path'));
      expect(migration, contains('(storage.foldername(p_name))[2]'));
      expect(
        migration,
        contains(r"'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'"),
      );
    });

    test('purge honors storage.protect_delete via the allow_delete_query GUC', () {
      expect(migration, contains("set_config('storage.allow_delete_query', 'true', true)"));
      expect(migration, contains("set_config('storage.allow_delete_query', 'false', true)"));
      expect(migration, contains('WHERE bucket_id = \'campaign-media\''));
    });
  });

  group('040 — security posture + idempotency', () {
    test('REVOKE-before-GRANT on every touched table; anon excluded', () {
      for (final table in ['campaign_targets', 'campaign_media', 'approval_requests', 'campaigns', 'campaign_banners']) {
        expect(
          migration,
          contains('REVOKE ALL ON public.$table FROM anon, authenticated'),
          reason: table,
        );
      }
    });

    test('no DELETE grant on campaigns; approval_requests SELECT-only', () {
      expect(
        migration,
        contains('GRANT SELECT, INSERT, UPDATE ON public.campaigns TO authenticated'),
      );
      expect(migration, isNot(contains('DELETE ON public.campaigns TO authenticated')));
      expect(
        migration,
        contains('GRANT SELECT ON public.approval_requests TO authenticated'),
      );
      expect(
        migration,
        isNot(contains('GRANT INSERT ON public.approval_requests')),
      );
      expect(
        migration,
        isNot(contains('GRANT UPDATE ON public.approval_requests')),
      );
    });

    test('client inserts always land in draft (lifecycle stays RPC-only)', () {
      expect(migration, contains("NEW.status := 'draft';"));
      expect(migration, contains('campaigns_set_creator'));
      expect(migration, contains('BEFORE INSERT OR UPDATE ON public.campaigns'));
    });

    test('idempotent/additive: IF NOT EXISTS + ON CONFLICT + DROP IF EXISTS everywhere', () {
      expect(migration, contains('BEGIN;'));
      expect(migration, contains('COMMIT;'));
      expect(RegExp('CREATE TABLE IF NOT EXISTS').allMatches(migration).length, 3);
      expect(RegExp('CREATE INDEX IF NOT EXISTS|CREATE UNIQUE INDEX IF NOT EXISTS').allMatches(migration).length, 6);
      expect(RegExp('DROP POLICY IF EXISTS').allMatches(migration).length, 18);
      expect(RegExp('CREATE POLICY').allMatches(migration).length, 18);
      expect(RegExp('DROP TRIGGER IF EXISTS').allMatches(migration).length, 2);
      expect(RegExp('CREATE OR REPLACE FUNCTION').allMatches(migration).length, 14);
    });
  });
}
