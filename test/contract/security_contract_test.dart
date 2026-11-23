import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Security contract for the SQL surface.
///
/// Round 92's external sweep reported "29 admin functions executable by anon"
/// without reading a single function body. Most were fine; two were not, and
/// the difference between those two outcomes is exactly what this suite encodes.
///
/// A wallet RPC is never anonymous. The bug was a guard written as
/// `auth.uid() IS NOT NULL AND p_user_id IS DISTINCT FROM auth.uid()`, which a
/// signed-out caller skips entirely. These tests fail if that shape returns, if
/// an identity-document path view comes back, or if the migration that fixed it
/// stops being applied.
void main() {
  List<File> sqlFiles() => <File>[
    for (final migrations in [
      Directory('supabase/migrations_archive'),
      Directory('supabase/migrations'),
    ])
      if (migrations.existsSync())
        ...migrations.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.sql'),
        ),
  ]..sort((a, b) => a.path.compareTo(b.path));

  String read(File f) => f.readAsStringSync();
  String all() => sqlFiles().map(read).join('\n');

  group('wallet RPCs are never anonymously callable', () {
    test('no wallet function guards with an IS NOT NULL conjunction', () {
      // The dangerous form. `auth.uid() IS NOT NULL AND ...` is a no-op for a
      // signed-out caller; `auth.uid() IS NULL OR ...` fails closed.
      final offenders = <String>[];
      for (final f in sqlFiles()) {
        final lines = read(f).split('\n');
        for (var i = 0; i < lines.length; i++) {
          final l = lines[i];
          if (!l.contains('auth.uid()')) continue;
          if (!RegExp(
            r'auth\.uid\(\)\s+IS\s+NOT\s+NULL\s+AND.*IS\s+DISTINCT\s+FROM',
          ).hasMatch(l)) {
            continue;
          }
          // A wallet function in scope of this line?
          final window = lines
              .sublist((i - 25).clamp(0, lines.length), i + 1)
              .join('\n');
          if (window.contains('FUNCTION public.wallet_'))
            offenders.add(l.trim());
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a wallet RPC must reject auth.uid() IS NULL, not skip the check',
      );
    });

    test('every wallet RPC rejects a null uid explicitly', () {
      final sql = all();
      for (final fn in ['wallet_topup', 'wallet_pay']) {
        expect(
          sql.contains('CREATE OR REPLACE FUNCTION public.$fn('),
          isTrue,
          reason:
              '$fn must be redefined in a migration so its guard is reviewable',
        );
      }
      expect(
        RegExp(
          r'auth\.uid\(\)\s+IS\s+NULL\s+OR\s+p_user_id\s+IS\s+DISTINCT\s+FROM\s+auth\.uid\(\)',
        ).hasMatch(sql),
        isTrue,
        reason:
            'the fail-closed wallet guard must exist in the migration history',
      );
    });

    test('anon is revoked from the user_id-taking wallet overloads', () {
      final sql = all();
      for (final sig in [
        'wallet_topup(uuid, numeric, text, text, uuid)',
        'wallet_pay(uuid, numeric, text, text, uuid)',
      ]) {
        expect(
          sql.contains('REVOKE ALL ON FUNCTION public.$sig FROM anon;'),
          isTrue,
          reason:
              'the $sig overload accepts a caller-supplied user and must be '
              'closed to anon',
        );
      }
    });
  });

  group('identity documents are not enumerable', () {
    test('no migration recreates the legacy identity path view', () {
      // 103 moved the documents to a private bucket; 114 dropped the view that
      // survived that migration. Recreating it would republish the inventory.
      for (final f in sqlFiles()) {
        if (f.path.endsWith('103_private_identity_documents.sql')) continue;
        expect(
          read(f).contains('CREATE VIEW public.legacy_identity_document_paths'),
          isFalse,
          reason:
              '${f.path} recreates a view over storage.objects that '
              'exposes identity document paths to anon',
        );
      }
    });

    test('the drop is recorded so a rebuild reproduces the fix', () {
      expect(
        all().contains(
          'DROP VIEW IF EXISTS public.legacy_identity_document_paths;',
        ),
        isTrue,
      );
    });
  });

  group('client-facing SECURITY DEFINER functions are pinned', () {
    test(
      'no public SECURITY DEFINER function is created without search_path',
      () {
        final offenders = <String>[];
        // Look at the CREATE itself: `SECURITY DEFINER` in the header with no
        // `SET search_path` anywhere in the statement.
        final stmt = RegExp(
          r'CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\s+public\.([a-z_0-9]+)\s*\(.*?\$\$[\s\S]*?\$\$;\s*',
          caseSensitive: false,
        );
        for (final f in sqlFiles()) {
          for (final m in stmt.allMatches(read(f))) {
            final header = m.group(0)!;
            if (!header.toUpperCase().contains('SECURITY DEFINER')) continue;
            if (header.toUpperCase().contains('SEARCH_PATH')) continue;
            offenders.add('${f.path}: ${m.group(2)}');
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'a SECURITY DEFINER function resolves unqualified names with the '
              "caller's search_path; pin it to public, pg_temp",
        );
      },
    );

    test('the pinning sweep exists in the migration history', () {
      expect(all().contains('SET search_path = public, pg_temp'), isTrue);
    });
  });

  group('RLS-only tables declare their intent', () {
    test('the commission ledger tables state that RPCs are the only path', () {
      final sql = all();
      for (final t in [
        'commission_rules',
        'platform_commissions',
        'driver_earnings',
      ]) {
        expect(
          sql.contains('COMMENT ON TABLE public.$t IS'),
          isTrue,
          reason:
              '$t has RLS enabled with no policy; the intent must be written '
              'down so a later migration does not widen it unknowingly',
        );
      }
    });
  });

  group('the migration log is honest', () {
    test('every fix from round 92 is present as a reviewable migration', () {
      final names = sqlFiles().map((f) => f.path.split('/').last).toList();
      expect(names.any((n) => n.startsWith('113_')), isTrue);
      expect(names.any((n) => n.startsWith('114_')), isTrue);
      // The 111/112 pair fixed the commission ambiguity in round 91.
      expect(names.any((n) => n.startsWith('111_')), isTrue);
      expect(names.any((n) => n.startsWith('112_')), isTrue);
    });

    test('migration filenames are zero padded so lexical order is real order', () {
      // Sorting by name is how the migration history reads, so the number must
      // be fixed width. (Duplicate numbers already exist in 002/003/032 from
      // earlier sprints; renumbering applied migrations is out of scope, but a
      // NEW migration must never introduce one.)
      final names = sqlFiles()
          .map((f) => f.path.split('/').last.split('_').first)
          .toList();
      for (final n in names) {
        // A version may carry a single-letter split suffix (424a/424b); the
        // numeric prefix must still be fixed-width.
        final m = RegExp(r'^(\d+)([a-z]?)$').firstMatch(n);
        expect(m, isNotNull, reason: 'migration version $n is malformed');
        expect(
          m!.group(1)!.length,
          3,
          reason: 'migration number $n is not zero padded',
        );
      }
      final counts = <String, int>{};
      for (final n in names) {
        counts[n] = (counts[n] ?? 0) + 1;
      }
      final duplicates = counts.entries
          .where(
            (e) =>
                e.value > 1 &&
                int.parse(RegExp(r'^(\d+)').firstMatch(e.key)!.group(1)!) >=
                    100,
          )
          .map((e) => e.key)
          .toList();
      expect(
        duplicates,
        isEmpty,
        reason: 'migrations 100+ must be uniquely numbered',
      );
    });
  });
}
