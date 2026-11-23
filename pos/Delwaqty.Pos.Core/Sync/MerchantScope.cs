using System;
using System.Collections.Generic;
using System.IO;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>
    /// Merchant-keyed local data layout (review #116). Previously every local
    /// database sat directly in the shared data dir, so deactivating merchant
    /// A and activating merchant B made A's queued outbox upload under B.
    /// All per-merchant data now lives under
    ///   &lt;root&gt;/merchants/&lt;merchantId&gt;-&lt;flavor&gt;/
    /// and a scope is never shared. Device-bound files (device.id,
    /// device.key) stay at the root.
    /// </summary>
    public static class MerchantScope
    {
        public const string MerchantsDirName = "merchants";

        /// <summary>Files that are per-merchant and move into the scope dir.</summary>
        public static readonly string[] ScopedFiles =
        {
            "license.seal", "session.cred",
            "outbox.db", "sales.db", "batches.db", "pos.db",
            "catalog.db", "products.db", "shift.json",
        };

        public static string ScopeDirName(string merchantId, string flavor)
        {
            return Sanitize(merchantId) + "-" + (flavor ?? "").Trim().ToLowerInvariant();
        }

        public static string ScopeDir(string rootDir, string merchantId, string flavor)
        {
            return Path.Combine(rootDir, MerchantsDirName, ScopeDirName(merchantId, flavor));
        }

        /// <summary>All existing scope dirs (any merchant, any flavor).</summary>
        public static List<string> ExistingScopes(string rootDir)
        {
            var list = new List<string>();
            var baseDir = Path.Combine(rootDir, MerchantsDirName);
            if (Directory.Exists(baseDir)) list.AddRange(Directory.GetDirectories(baseDir));
            return list;
        }

        private static string Sanitize(string merchantId)
        {
            var s = (merchantId ?? "unknown").Trim();
            foreach (var c in Path.GetInvalidFileNameChars()) s = s.Replace(c, '-');
            return s.Length == 0 ? "unknown" : s;
        }

        /// <summary>
        /// One-time upgrade: pre-#116 installs kept every per-merchant file at
        /// the root. Move them into the merchant's scope dir (no overwrite).
        /// Returns the moved file names (for tests/diagnostics).
        /// </summary>
        public static List<string> MigrateLegacyRootData(string rootDir, string scopeDir)
        {
            var moved = new List<string>();
            Directory.CreateDirectory(scopeDir);
            foreach (var name in ScopedFiles)
            {
                var from = Path.Combine(rootDir, name);
                var to = Path.Combine(scopeDir, name);
                if (!File.Exists(from) || File.Exists(to)) continue;
                File.Move(from, to);
                moved.Add(name);
            }
            return moved;
        }

        /// <summary>
        /// Cross-merchant guard (review #116): refuses to activate a different
        /// merchant while another scope still has unsynced outbox ops — those
        /// rows belong to the old merchant and must upload first.
        /// Returns the offending scope dir, or null when activation is safe.
        /// </summary>
        public static string ScopeWithPendingOps(string rootDir, string exceptScopeDir)
        {
            foreach (var scope in ExistingScopes(rootDir))
            {
                if (string.Equals(Path.GetFullPath(scope), Path.GetFullPath(exceptScopeDir),
                        StringComparison.OrdinalIgnoreCase))
                    continue;
                var outboxPath = Path.Combine(scope, "outbox.db");
                var posPath = Path.Combine(scope, "pos.db");
                try
                {
                    if (File.Exists(outboxPath))
                    {
                        using (var store = new OutboxStore(outboxPath))
                            if (store.PendingCount() > 0) return scope;
                    }
                    if (File.Exists(posPath))
                    {
                        using (var db = new PosLocalDb(posPath, importLegacy: false))
                            if (db.Outbox.PendingCount() > 0) return scope;
                    }
                }
                catch
                {
                    // FAIL CLOSED (review #116 follow-up): a scope we cannot
                    // read may hold unsynced ops; activating another merchant
                    // over it could strand them. Block and let support look.
                    return scope;
                }
            }
            return null;
        }
    }
}
