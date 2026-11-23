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

        private readonly SqliteConnection _db;

        public BatchStore(string path)
        {
            var cs = new SqliteConnectionStringBuilder { DataSource = path }.ToString();
            _db = new SqliteConnection(cs);
            _db.Open();
            using (var cmd = _db.CreateCommand())
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
                    "CREATE INDEX IF NOT EXISTS batches_item ON batches(item_key, expiry);";
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>Record a restock batch (شراء/توريد).</summary>
        public long AddBatch(string itemKey, string itemName, decimal qty, DateTime expiryDate, string batchNo)
        {
            if (qty <= 0) throw new ArgumentOutOfRangeException("qty");
            using (var cmd = _db.CreateCommand())
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

        /// <summary>Batches of one item that still have stock, FEFO order (soonest expiry first).</summary>
        public List<Batch> BatchesFor(string itemKey)
        {
            var list = new List<Batch>();
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "SELECT id, item_key, item_name, qty, expiry, batch_no, created_at FROM batches" +
                    " WHERE item_key = $k AND qty > 0 ORDER BY expiry ASC, id ASC;";
                cmd.Parameters.AddWithValue("$k", itemKey ?? "");
                using (var r = cmd.ExecuteReader()) while (r.Read()) list.Add(Read(r));
            }
            return list;
        }

        /// <summary>
        /// FEFO allocation: which batches to dispense for a sale of qty.
        /// Returns (batchId, qty) pairs in dispense order; empty when no
        /// batches are tracked for the item (untracked stock is allowed).
        /// </summary>
        public List<KeyValuePair<long, decimal>> AllocateFefo(string itemKey, decimal qty)
        {
            var result = new List<KeyValuePair<long, decimal>>();
            if (qty <= 0) return result;
            var remaining = qty;
            foreach (var b in BatchesFor(itemKey))
            {
                if (remaining <= 0) break;
                var take = Math.Min(b.QtyOnHand, remaining);
                if (take > 0)
                {
                    result.Add(new KeyValuePair<long, decimal>(b.Id, take));
                    remaining -= take;
                }
            }
            return result;
        }

        /// <summary>Decrement a batch after a sale. Clamps at zero.</summary>
        public void Decrement(long batchId, decimal qty)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "UPDATE batches SET qty = MAX(0, qty - $q) WHERE id = $id;";
                cmd.Parameters.AddWithValue("$q", qty);
                cmd.Parameters.AddWithValue("$id", batchId);
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>Sell helper: FEFO-allocate and decrement in one call.</summary>
        public void Dispense(string itemKey, decimal qty)
        {
            foreach (var pair in AllocateFefo(itemKey, qty)) Decrement(pair.Key, pair.Value);
        }

        /// <summary>
        /// Expiry alerts: batches with stock expiring on or before the cutoff,
        /// soonest first. Already-expired batches come first (expiry in the past).
        /// </summary>
        public List<Batch> ExpiringSoon(DateTime cutoffDate, int limit)
        {
            var list = new List<Batch>();
            using (var cmd = _db.CreateCommand())
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

        /// <summary>Total tracked on-hand for an item across batches.</summary>
        public decimal TrackedQty(string itemKey)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText = "SELECT COALESCE(SUM(qty), 0) FROM batches WHERE item_key = $k;";
                cmd.Parameters.AddWithValue("$k", itemKey ?? "");
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

        public void Dispose() { _db.Dispose(); }
    }
}
