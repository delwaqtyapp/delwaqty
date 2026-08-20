import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates migration 042 (customer campaign feed RPC) against the SQL file
/// as the single source of truth. The RPC must be customer-facing only,
/// region-scoped (national OR ancestor chain), banner-joined, and never grant
/// anon/pubic execution.
void main() {
  final migration = File('supabase/migrations/042_campaign_feed_rpc.sql')
      .readAsStringSync()
      .replaceAll('\r\n', '\n');

  group('042 — _campaign_region_visible helper', () {
    test('exists and is SECURITY DEFINER STABLE', () {
      expect(
        migration,
        contains("CREATE OR REPLACE FUNCTION public._campaign_region_visible("),
      );
      expect(migration, contains('LANGUAGE sql'));
      expect(migration, contains('STABLE'));
      expect(migration, contains('SECURITY DEFINER'));
    });

    test('checks national (NULL), self, and ancestor chain on campaign_targets', () {
      expect(migration, contains('SELECT 1'));
      expect(migration, contains('FROM public.campaign_targets t'));
      expect(migration, contains('t.region_id IS NULL'));
      expect(migration, contains('t.region_id = p_member_region'));
      expect(migration, contains('WITH RECURSIVE region_chain AS ('));
      expect(migration, contains('SELECT p_member_region AS region_id'));
      expect(migration, contains('JOIN region_chain rc ON r.id = rc.region_id'));
    });
  });

  group('042 — feed RPC contract', () {
    test('defines get_active_campaigns(p_locale default ar)', () {
      expect(
        migration,
        contains("CREATE OR REPLACE FUNCTION public.get_active_campaigns(p_locale text DEFAULT 'ar')"),
      );
      expect(migration, contains('RETURNS TABLE ('));
      expect(migration, contains('image_path         text,'));
      expect(migration, contains('cta                jsonb'));
    });

    test('is SECURITY DEFINER with pinned search_path and STABLE', () {
      expect(migration, contains('LANGUAGE plpgsql'));
      expect(migration, contains('STABLE'));
      expect(migration, contains('SECURITY DEFINER'));
      expect(migration, contains('SET search_path = public, pg_temp'));
    });

    test('requires a session user and resolves the member region', () {
      expect(migration, contains('v_uid    uuid := auth.uid();'));
      expect(migration, contains('IF v_uid IS NULL THEN'));
      expect(migration, contains('public._member_region_id(v_uid)'));
    });

    test('filters published, non-archived, schedule-open campaigns', () {
      expect(migration, contains("c.status = 'published'"));
      expect(migration, contains('c.archived_at IS NULL'));
      expect(migration, contains('(c.starts_at IS NULL OR c.starts_at <= now())'));
      expect(migration, contains('(c.ends_at IS NULL OR c.ends_at >= now())'));
    });

    test('banner join is lateral, active home_carousel, locale-matched', () {
      expect(migration, contains('LEFT JOIN LATERAL ('));
      expect(migration, contains("cb.placement = 'home_carousel'"));
      expect(migration, contains('cb.is_active'));
      expect(migration, contains('cb.locale = p_locale'));
      expect(migration, contains('ORDER BY cb.priority ASC, cb.created_at DESC'));
    });

    test('orders by priority then recency', () {
      expect(
        migration,
        contains('ORDER BY c.priority DESC, c.published_at DESC NULLS LAST'),
      );
    });

    test('revokes public/anon and grants only authenticated + service_role', () {
      expect(
        migration,
        contains('REVOKE ALL ON FUNCTION public.get_active_campaigns(text) FROM PUBLIC;'),
      );
      expect(
        migration,
        contains('REVOKE ALL ON FUNCTION public.get_active_campaigns(text) FROM anon;'),
      );
      expect(
        migration,
        contains('GRANT EXECUTE ON FUNCTION public.get_active_campaigns(text)\n  TO authenticated, service_role;'),
      );
      expect(
        migration,
        contains('REVOKE ALL ON FUNCTION public._campaign_region_visible(uuid, uuid) FROM PUBLIC;'),
      );
    });

    test('feed RPC delegates region check to _campaign_region_visible', () {
      expect(
        migration,
        contains('public._campaign_region_visible(c.id, v_region)'),
      );
    });
  });
}
