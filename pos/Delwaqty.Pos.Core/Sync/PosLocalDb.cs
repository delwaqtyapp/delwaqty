using System;
using System.Collections.Generic;
using System.IO;
using Delwaqty.Pos.Core.Pharmacy;
using Delwaqty.Pos.Core.Sales;
using Microsoft.Data.Sqlite;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>
    /// One SQLite file (pos.db) hosting every per-merchant local store over a
    /// single connection, so a sale commit — outbox op + sales journal +
    /// batch movements + allocation rows — is ONE transaction (review #120:
    /// dispensing must be atomic with the local sale, not after the outbox
    /// commit). A void is equally atomic (void op + journal mark + batch
    /// restore).
    ///
    /// Upgrade path: legacy installs had outbox.db / sales.db / batches.db as
    /// separate files in the same directory; ImportLegacyDb copies their rows
    /// in once and renames the old file aside.
    /// </summary>
    public sealed class PosLocalDb : IDisposable
    {
        private readonly SqliteConnection _db;

        public readonly OutboxStore Outbox;
        public readonly LocalSalesLog Sales;
        public readonly BatchStore Batches;

        /// <summary>
        /// Non-null when a legacy import failed or its row counts did not add
        /// up (review #120 migration follow-up): the legacy file is kept in
        /// place, but the app must show a visible repair state and refuse
        /// selling and sync until support looks — silently proceeding with an
        /// empty pos.db would orphan queued sales.
        /// </summary>
        public string RepairState { get; private set; }

        /// <summary>Rows imported per legacy table (diagnostics/tests).</summary>
        public readonly Dictionary<string, int> ImportedCounts = new Dictionary<string, int>();

        public PosLocalDb(string path) : this(path, importLegacy: true) { }

        public PosLocalDb(string path, bool importLegacy)
        {
            _db = OutboxStore.Open(path);
            Outbox = new OutboxStore(_db, false);
            Sales = new LocalSalesLog(_db, false);
            Batches = new BatchStore(_db, false);
            if (importLegacy)
            {
                var dir = Path.GetDirectoryName(path);
                if (!string.IsNullOrEmpty(dir))
                {
                    ImportLegacyDb(dir, "outbox.db", "outbox", "op_id");
                    ImportLegacyDb(dir, "sales.db", "local_sales", "op_id");
                    ImportLegacyDb(dir, "batches.db", "batches", "id");
                }
            }
        }

        /// <summary>
        /// Run body inside one IMMEDIATE transaction across all stores.
        /// Rolls back on any exception, so a half-written sale is impossible.
        /// </summary>
        public void Tx(Action body)
        {
            using (var tx = _db.BeginTransaction())
            {
                Outbox.Tx = tx; Sales.Tx = tx; Batches.Tx = tx;
                try
                {
                    body();
                    tx.Commit();
                }
                finally
                {
                    Outbox.Tx = null; Sales.Tx = null; Batches.Tx = null;
                }
            }
        }

        /// <summary>
        /// The one way a sale lands locally (review #120): outbox op, sales
        /// journal row and FEFO batch dispensing commit together.
        /// Batch movements are recorded per sale so a void restores exactly.
        /// </summary>
        public void CommitSale(OutboxOp op, SaleBuilder sale, string localShiftId, bool dispenseBatches)
        {
            Tx(() =>
            {
                // #120 follow-up: coverage is verified BEFORE anything is
                // written, inside the same transaction — a tracked item whose
                // sellable (unexpired) batches do not cover the line aborts
                // the WHOLE sale (outbox op, journal row, every batch
                // movement roll back together). Untracked items (no batches
                // ever recorded) are the explicit exception: they sell
                // without batch dispensing, as documented for quick lines.
                if (dispenseBatches)
                {
                    foreach (var line in sale.Lines)
                    {
                        var key = line.ProductId ?? line.DrugCatalogId;
                        if (key == null) continue;
                        if (Batches.TrackedQty(key) <= 0) continue; // untracked: sells freely
                        var plan = Batches.AllocateFefo(key, line.Qty);
                        if (!plan.Covered)
                            throw new InvalidOperationException(
                                "INSUFFICIENT_TRACKED_STOCK:" + key + ":missing " + plan.Missing);
                    }
                }
                Outbox.Enqueue(op);
                Sales.Add(new LocalSalesLog.OutboxOpRef(op.OpId), sale, localShiftId);
                if (dispenseBatches)
                {
                    foreach (var line in sale.Lines)
                    {
                        var key = line.ProductId ?? line.DrugCatalogId;
                        if (key != null && Batches.TrackedQty(key) > 0)
                            Batches.Dispense(key, line.Qty, op.OpId);
                    }
                }
            });
        }

        /// <summary>
        /// Atomic void: void op enqueued, journal marked, batch quantities
        /// restored — all or nothing.
        /// </summary>
        public void VoidSale(OutboxOp voidOp, string saleOpId)
        {
            Tx(() =>
            {
                Outbox.Enqueue(voidOp);
                Sales.MarkVoided(saleOpId);
                Batches.RestoreForVoid(saleOpId);
            });
        }

        /// <summary>
        /// Copy rows from a legacy single-table db file in the same directory
        /// into pos.db, then rename the file to &lt;name&gt;.migrated. Idempotent
        /// (INSERT OR IGNORE); a missing or empty legacy file is skipped.
        /// </summary>
        private void ImportLegacyDb(string dir, string fileName, string table, string pk)
        {
            var legacy = Path.Combine(dir, fileName);
            if (!File.Exists(legacy)) return;
            try
            {
                using (var attach = _db.CreateCommand())
                {
                    attach.CommandText = "ATTACH DATABASE $p AS legacy;";
                    attach.Parameters.AddWithValue("$p", legacy);
                    attach.ExecuteNonQuery();
                }
                try
                {
                    var cols = LegacyColumns(table);
                    // Assert the counts (review #120 migration follow-up):
                    // every legacy row must land in main unless its key is
                    // already there (idempotent re-import).
                    long legacyCount, alreadyThere, before, after;
                    using (var cmd = _db.CreateCommand())
                    {
                        cmd.CommandText = "SELECT COUNT(*) FROM legacy." + table + ";";
                        legacyCount = (long)cmd.ExecuteScalar();
                    }
                    using (var cmd = _db.CreateCommand())
                    {
                        cmd.CommandText = "SELECT COUNT(*) FROM legacy." + table +
                            " WHERE " + pk + " IN (SELECT " + pk + " FROM main." + table + ");";
                        alreadyThere = (long)cmd.ExecuteScalar();
                    }
                    using (var cmd = _db.CreateCommand())
                    {
                        cmd.CommandText = "SELECT COUNT(*) FROM main." + table + ";";
                        before = (long)cmd.ExecuteScalar();
                    }
                    using (var cmd = _db.CreateCommand())
                    {
                        cmd.CommandText = "INSERT OR IGNORE INTO main." + table +
                            " (" + cols + ") SELECT " + cols + " FROM legacy." + table + ";";
                        cmd.ExecuteNonQuery();
                    }
                    using (var cmd = _db.CreateCommand())
                    {
                        cmd.CommandText = "SELECT COUNT(*) FROM main." + table + ";";
                        after = (long)cmd.ExecuteScalar();
                    }
                    var inserted = after - before;
                    ImportedCounts[table] = (int)inserted;
                    if (inserted + alreadyThere != legacyCount)
                    {
                        RepairState = "legacy import of " + fileName + " lost rows (" +
                            legacyCount + " legacy, " + alreadyThere + " existing, " + inserted + " inserted)";
                        return; // keep the legacy file in place
                    }
                }
                finally
                {
                    using (var detach = _db.CreateCommand())
                    {
                        detach.CommandText = "DETACH DATABASE legacy;";
                        detach.ExecuteNonQuery();
                    }
                }
                File.Move(legacy, legacy + ".migrated");
            }
            catch (Exception ex)
            {
                // The file stays in place and the app must surface a repair
                // state instead of running on a silently empty pos.db.
                RepairState = "legacy import of " + fileName + " failed: " + ex.Message;
            }
        }

        private static string LegacyColumns(string table)
        {
            switch (table)
            {
                case "outbox":
                    return "op_id, type, payload, created_offline_at, attempts, synced";
                case "local_sales":
                    return "op_id, shift_id, total, payments, customer_id, customer_name, status, created_at";
                case "batches":
                    return "id, item_key, item_name, qty, expiry, batch_no, created_at";
                default:
                    throw new ArgumentException(table);
            }
        }

        public void Dispose() { _db.Dispose(); }
    }
}
