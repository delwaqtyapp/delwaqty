using System;
using System.Collections.Generic;
using Microsoft.Data.Sqlite;

namespace Delwaqty.Pos.Core.Pharmacy
{
    /// <summary>
    /// Local batch/expiry tracking for the pharmacy flavor (تشغيلات وتواريخ
    /// صلاحية). The platform schema has no batch tables yet, so v1 keeps this
    /// on the device: batches are recorded here, FEFO (first-expiry-first-out)
    /// suggests which batch to dispense, and an alerts query lists what
    /// expires soon. Absolute stock stays server-side (products.stock_quantity
    /// via stock_count ops); this store is the per-batch breakdown.
    ///
    /// Review #120 fixes:
    /// - Expired batches are ineligible for FEFO (they used to be consumed
    ///   FIRST, which is the worst possible order); they surface separately
    ///   via ExpiredFor for disposal.
    /// - Allocation reports shortfall (Missing) instead of silently
    ///   dispensing less than the sold quantity.
    /// - Every dispense records per-sale batch allocations, and a void
    ///   restores those exact quantities.
    /// - Dispense happens in the caller's transaction (PosLocalDb.Tx), so
    ///   batch movement, the sale journal and the outbox op commit or roll
    ///   back together.
    /// </summary>
    public sealed class BatchStore : IDisposable
    {
        public sealed class Batch
        {
            public long Id;
            public string ItemKey;      // product_id or drug_catalog_id
            public string ItemName;
            public decimal QtyOnHand;
            public DateTime ExpiryDate; // date only
            public string BatchNo;
            public DateTimeOffset CreatedAt;
        }

        /// <summary>FEFO allocation result. Covered = no shortfall.</summary>
        public sealed class Allocation
        {
            public readonly List<KeyValuePair<long, decimal>> Items = new List<KeyValuePair<long, decimal>>();
            public decimal Requested;
            public decimal Allocated;
            public decimal Missing { get { return Requested - Allocated; } }
            public bool Covered { get { return Missing <= 0m; } }
        }

        private readonly SqliteConnection _db;
        private readonly bool _ownsConnection;
        internal SqliteTransaction Tx;

        public BatchStore(string path) : this(Sync.OutboxStore.Open(path), true) { }

        internal BatchStore(SqliteConnection db, bool ownsConnection)
        {
            _db = db;
            _ownsConnection = ownsConnection;
            EnsureSchema();
        }

        internal SqliteCommand Cmd()
        {
            var cmd = _db.CreateCommand();
            if (Tx != null) cmd.Transaction = Tx;
            return cmd;
        }

        private void EnsureSchema()
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "CREATE TABLE IF NOT EXISTS batches (" +
                    " id INTEGER PRIMARY KEY AUTOINCREMENT," +
                    " item_key TEXT NOT NULL," +
                    " item_name TEXT NOT NULL," +
                    " qty REAL NOT NULL," +
                    " expiry TEXT NOT NULL," +
                    " batch_no TEXT," +
                    " created_at TEXT NOT NULL);" +
                    "CREATE INDEX IF NOT EXISTS batches_item ON batches(item_key, expiry);" +
                    // Per-sale allocation journal (#120): makes a void an exact
                    // quantity restore instead of a guess.
                    "CREATE TABLE IF NOT EXISTS batch_allocations (" +
                    " id INTEGER PRIMARY KEY AUTOINCREMENT," +
                    " sale_op_id TEXT NOT NULL," +
                    " batch_id INTEGER NOT NULL," +
                    " qty REAL NOT NULL," +
                    " voided INTEGER NOT NULL DEFAULT 0," +
                    " created_at TEXT NOT NULL);" +
                    "CREATE INDEX IF NOT EXISTS batch_alloc_sale ON batch_allocations(sale_op_id, voided);";
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>Record a restock batch (شراء/توريد).</summary>
        public long AddBatch(string itemKey, string itemName, decimal qty, DateTime expiryDate, string batchNo)
        {
            if (qty <= 0) throw new ArgumentOutOfRangeException("qty");
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "INSERT INTO batches (item_key, item_name, qty, expiry, batch_no, created_at)" +
                    " VALUES ($k, $n, $q, $e, $b, $c); SELECT last_insert_rowid();";
                cmd.Parameters.AddWithValue("$k", itemKey ?? "");
                cmd.Parameters.AddWithValue("$n", itemName ?? "");
                cmd.Parameters.AddWithValue("$q", qty);
                cmd.Parameters.AddWithValue("$e", expiryDate.Date.ToString("yyyy-MM-dd"));
                cmd.Parameters.AddWithValue("$b", (object)batchNo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$c", DateTimeOffset.UtcNow.ToString("o"));
                return Convert.ToInt64(cmd.ExecuteScalar());
            }
        }

        /// <summary>
        /// Sellable batches of one item that still have stock, FEFO order
        /// (soonest expiry first). Expired batches are EXCLUDED (#120) — use
        /// ExpiredFor for the disposal view.
        /// </summary>
        public List<Batch> BatchesFor(string itemKey)
        {
            return BatchesFor(itemKey, DateTime.Today);
        }

        public List<Batch> BatchesFor(string itemKey, DateTime asOfDate)
        {
            var list = new List<Batch>();
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "SELECT id, item_key, item_name, qty, expiry, batch_no, created_at FROM batches" +
                    " WHERE item_key = $k AND qty > 0 AND expiry >= $today ORDER BY expiry ASC, id ASC;";
                cmd.Parameters.AddWithValue("$k", itemKey ?? "");
                cmd.Parameters.AddWithValue("$today", asOfDate.Date.ToString("yyyy-MM-dd"));
                using (var r = cmd.ExecuteReader()) while (r.Read()) list.Add(Read(r));
            }
            return list;
        }

        /// <summary>Expired batches that still carry stock (write-off view).</summary>
        public List<Batch> ExpiredFor(string itemKey)
        {
            var list = new List<Batch>();
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "SELECT id, item_key, item_name, qty, expiry, batch_no, created_at FROM batches" +
                    " WHERE item_key = $k AND qty > 0 AND expiry < $today ORDER BY expiry ASC, id ASC;";
                cmd.Parameters.AddWithValue("$k", itemKey ?? "");
                cmd.Parameters.AddWithValue("$today", DateTime.Today.ToString("yyyy-MM-dd"));
                using (var r = cmd.ExecuteReader()) while (r.Read()) list.Add(Read(r));
            }
            return list;
        }

        /// <summary>
        /// FEFO allocation plan for a sale of qty. Never dispenses expired
        /// stock; reports Missing when the tracked sellable stock does not
        /// cover the request (#120). Empty Items with Missing == qty when the
        /// item has no tracked batches (untracked stock is allowed to sell).
        /// </summary>
        public Allocation AllocateFefo(string itemKey, decimal qty)
        {
            return AllocateFefo(itemKey, qty, DateTime.Today);
        }

        public Allocation AllocateFefo(string itemKey, decimal qty, DateTime asOfDate)
        {
            var result = new Allocation { Requested = qty };
            if (qty <= 0) return result;
            var remaining = qty;
            foreach (var b in BatchesFor(itemKey, asOfDate))
            {
                if (remaining <= 0) break;
                var take = Math.Min(b.QtyOnHand, remaining);
                if (take > 0)
                {
                    result.Items.Add(new KeyValuePair<long, decimal>(b.Id, take));
                    remaining -= take;
                }
            }
            result.Allocated = qty - remaining;
            return result;
        }

        /// <summary>Decrement a batch after a sale. Clamps at zero.</summary>
        public void Decrement(long batchId, decimal qty)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "UPDATE batches SET qty = MAX(0, qty - $q) WHERE id = $id;";
                cmd.Parameters.AddWithValue("$q", qty);
                cmd.Parameters.AddWithValue("$id", batchId);
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>
        /// FEFO-dispense for a sale: decrements the batches and records the
        /// per-sale allocation rows so a later void restores exactly these
        /// quantities. Runs inside the caller's transaction when one is set
        /// (PosLocalDb) — the sale, its journal row and the batch movement
        /// commit together (#120).
        /// </summary>
        public Allocation Dispense(string itemKey, decimal qty, string saleOpId)
        {
            var plan = AllocateFefo(itemKey, qty);
            foreach (var pair in plan.Items)
            {
                Decrement(pair.Key, pair.Value);
                if (saleOpId != null) RecordAllocation(saleOpId, pair.Key, pair.Value);
            }
            return plan;
        }

        private void RecordAllocation(string saleOpId, long batchId, decimal qty)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "INSERT INTO batch_allocations (sale_op_id, batch_id, qty, voided, created_at)" +
                    " VALUES ($s, $b, $q, 0, $c);";
                cmd.Parameters.AddWithValue("$s", saleOpId);
                cmd.Parameters.AddWithValue("$b", batchId);
                cmd.Parameters.AddWithValue("$q", qty);
                cmd.Parameters.AddWithValue("$c", DateTimeOffset.UtcNow.ToString("o"));
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>
        /// Restore the batch quantities a voided sale consumed (#120).
        /// Idempotent: allocations already marked voided are skipped.
        /// Returns the restored total quantity.
        /// </summary>
        public decimal RestoreForVoid(string saleOpId)
        {
            var rows = new List<KeyValuePair<long, KeyValuePair<long, decimal>>>();
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "SELECT id, batch_id, qty FROM batch_allocations WHERE sale_op_id = $s AND voided = 0;";
                cmd.Parameters.AddWithValue("$s", saleOpId);
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                        rows.Add(new KeyValuePair<long, KeyValuePair<long, decimal>>(
                            r.GetInt64(0), new KeyValuePair<long, decimal>(r.GetInt64(1), Convert.ToDecimal(r.GetDouble(2)))));
            }
            decimal restored = 0;
            foreach (var row in rows)
            {
                using (var cmd = Cmd())
                {
                    cmd.CommandText = "UPDATE batches SET qty = qty + $q WHERE id = $b;";
                    cmd.Parameters.AddWithValue("$q", row.Value.Value);
                    cmd.Parameters.AddWithValue("$b", row.Value.Key);
                    cmd.ExecuteNonQuery();
                }
                using (var cmd = Cmd())
                {
                    cmd.CommandText = "UPDATE batch_allocations SET voided = 1 WHERE id = $id;";
                    cmd.Parameters.AddWithValue("$id", row.Key);
                    cmd.ExecuteNonQuery();
                }
                restored += row.Value.Value;
            }
            return restored;
        }

        /// <summary>Allocations recorded for one sale (newest first), incl. voided.</summary>
        public List<(long BatchId, decimal Qty, bool Voided)> AllocationsFor(string saleOpId)
        {
            var list = new List<(long, decimal, bool)>();
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "SELECT batch_id, qty, voided FROM batch_allocations WHERE sale_op_id = $s ORDER BY id;";
                cmd.Parameters.AddWithValue("$s", saleOpId);
                using (var r = cmd.ExecuteReader())
                    while (r.Read())
                        list.Add((r.GetInt64(0), Convert.ToDecimal(r.GetDouble(1)), r.GetInt32(2) != 0));
            }
            return list;
        }

        /// <summary>
        /// Expiry alerts: batches with stock expiring on or before the cutoff,
        /// soonest first. Already-expired batches come first (expiry in the past).
        /// </summary>
        public List<Batch> ExpiringSoon(DateTime cutoffDate, int limit)
        {
            var list = new List<Batch>();
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "SELECT id, item_key, item_name, qty, expiry, batch_no, created_at FROM batches" +
                    " WHERE qty > 0 AND expiry <= $cut ORDER BY expiry ASC LIMIT $lim;";
                cmd.Parameters.AddWithValue("$cut", cutoffDate.Date.ToString("yyyy-MM-dd"));
                cmd.Parameters.AddWithValue("$lim", limit);
                using (var r = cmd.ExecuteReader()) while (r.Read()) list.Add(Read(r));
            }
            return list;
        }

        /// <summary>Total tracked on-hand for an item across batches (incl. expired).</summary>
        public decimal TrackedQty(string itemKey)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText = "SELECT COALESCE(SUM(qty), 0) FROM batches WHERE item_key = $k;";
                cmd.Parameters.AddWithValue("$k", itemKey ?? "");
                return Convert.ToDecimal(cmd.ExecuteScalar());
            }
        }

        /// <summary>Sellable (non-expired) tracked on-hand for an item.</summary>
        public decimal SellableQty(string itemKey)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "SELECT COALESCE(SUM(qty), 0) FROM batches WHERE item_key = $k AND expiry >= $today;";
                cmd.Parameters.AddWithValue("$k", itemKey ?? "");
                cmd.Parameters.AddWithValue("$today", DateTime.Today.ToString("yyyy-MM-dd"));
                return Convert.ToDecimal(cmd.ExecuteScalar());
            }
        }

        private static Batch Read(SqliteDataReader r)
        {
            return new Batch
            {
                Id = r.GetInt64(0),
                ItemKey = r.GetString(1),
                ItemName = r.GetString(2),
                QtyOnHand = Convert.ToDecimal(r.GetDouble(3)),
                ExpiryDate = DateTime.ParseExact(r.GetString(4), "yyyy-MM-dd", null),
                BatchNo = r.IsDBNull(5) ? null : r.GetString(5),
                CreatedAt = DateTimeOffset.Parse(r.GetString(6)),
            };
        }

        public void Dispose() { if (_ownsConnection) _db.Dispose(); }
    }
}
