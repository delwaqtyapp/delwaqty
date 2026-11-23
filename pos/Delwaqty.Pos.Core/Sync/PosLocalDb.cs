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
                    ImportLegacyDb(dir, "outbox.db", "outbox");
                    ImportLegacyDb(dir, "sales.db", "local_sales");
                    ImportLegacyDb(dir, "batches.db", "batches");
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
                Outbox.Enqueue(op);
                Sales.Add(new LocalSalesLog.OutboxOpRef(op.OpId), sale, localShiftId);
                if (dispenseBatches)
                {
                    foreach (var line in sale.Lines)
                    {
                        var key = line.ProductId ?? line.DrugCatalogId;
                        if (key != null) Batches.Dispense(key, line.Qty, op.OpId);
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
        private void ImportLegacyDb(string dir, string fileName, string table)
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
                    using (var cmd = _db.CreateCommand())
                    {
                        cmd.CommandText = "INSERT OR IGNORE INTO main." + table +
                            " (" + cols + ") SELECT " + cols + " FROM legacy." + table + ";";
                        cmd.ExecuteNonQuery();
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
            catch
            {
                // Never block startup on a legacy import problem; the file
                // stays in place for support.
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
