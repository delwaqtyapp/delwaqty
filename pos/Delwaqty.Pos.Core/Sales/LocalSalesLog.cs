using System;
using System.Collections.Generic;
using System.Text.Json;
using Delwaqty.Pos.Core.Close;
using Microsoft.Data.Sqlite;

namespace Delwaqty.Pos.Core.Sales
{
    /// <summary>
    /// Local record of sales made on this device. Feeds the offline
    /// daily-close estimate (DailyCloseCalculator), the void flow (a void
    /// needs the sale's op id, which is its idempotency key server-side),
    /// and receipt reprints. The server stays the source of truth; this is
    /// the device's own journal.
    /// </summary>
    public sealed class LocalSalesLog : IDisposable
    {
        public sealed class Entry
        {
            public string OpId;
            public string ShiftId;
            public decimal Total;
            public string PaymentsJson;
            public string CustomerId;
            public string CustomerName;
            public string Status;         // completed | voided
            public DateTimeOffset CreatedAt;
        }

        private readonly SqliteConnection _db;

        public LocalSalesLog(string path)
        {
            var cs = new SqliteConnectionStringBuilder { DataSource = path }.ToString();
            _db = new SqliteConnection(cs);
            _db.Open();
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "CREATE TABLE IF NOT EXISTS local_sales (" +
                    " op_id TEXT PRIMARY KEY," +
                    " shift_id TEXT," +
                    " total REAL NOT NULL," +
                    " payments TEXT NOT NULL DEFAULT '[]'," +
                    " customer_id TEXT," +
                    " customer_name TEXT," +
                    " status TEXT NOT NULL DEFAULT 'completed'," +
                    " created_at TEXT NOT NULL);" +
                    "CREATE INDEX IF NOT EXISTS local_sales_shift ON local_sales(shift_id);";
                cmd.ExecuteNonQuery();
            }
        }

        public void Add(OutboxOpRef op, SaleBuilder sale) { Add(op, sale, sale.ShiftId); }

        /// <summary>Add with an explicit local shift grouping id (the sale payload
        /// may carry the SERVER shift id while the local journal groups by the
        /// locally-known id until the server id is adopted).</summary>
        public void Add(OutboxOpRef op, SaleBuilder sale, string shiftId)
        {
            // Payment exposes fields, not properties: IncludeFields is required.
            var payments = JsonSerializer.Serialize(sale.Payments, FieldJson);
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "INSERT OR IGNORE INTO local_sales" +
                    " (op_id, shift_id, total, payments, customer_id, customer_name, status, created_at)" +
                    " VALUES ($id, $shift, $total, $pay, $cid, $cname, 'completed', $at);";
                cmd.Parameters.AddWithValue("$id", op.OpId);
                cmd.Parameters.AddWithValue("$shift", (object)shiftId ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$total", sale.Total);
                cmd.Parameters.AddWithValue("$pay", payments);
                cmd.Parameters.AddWithValue("$cid", (object)sale.CustomerId ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$cname", (object)sale.CustomerName ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("o"));
                cmd.ExecuteNonQuery();
            }
        }

        private static readonly JsonSerializerOptions FieldJson =
            new JsonSerializerOptions { IncludeFields = true };

        /// <summary>Small indirection so the log does not depend on OutboxOp.</summary>
        public sealed class OutboxOpRef
        {
            public string OpId;
            public OutboxOpRef(string opId) { OpId = opId; }
        }

        /// <summary>Reassign all rows of one local shift id to another (adopting
        /// the server shift id after the shift_open op syncs).</summary>
        public void RemapShift(string oldShiftId, string newShiftId)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText = "UPDATE local_sales SET shift_id = $new WHERE shift_id = $old;";
                cmd.Parameters.AddWithValue("$new", newShiftId);
                cmd.Parameters.AddWithValue("$old", oldShiftId);
                cmd.ExecuteNonQuery();
            }
        }

        public void MarkVoided(string opId)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText = "UPDATE local_sales SET status = 'voided' WHERE op_id = $id;";
                cmd.Parameters.AddWithValue("$id", opId);
                cmd.ExecuteNonQuery();
            }
        }

        public List<Entry> SalesForShift(string shiftId)
        {
            var list = new List<Entry>();
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "SELECT op_id, shift_id, total, payments, customer_id, customer_name, status, created_at" +
                    " FROM local_sales WHERE shift_id = $s ORDER BY created_at;";
                cmd.Parameters.AddWithValue("$s", shiftId ?? "");
                using (var r = cmd.ExecuteReader()) while (r.Read()) list.Add(Read(r));
            }
            return list;
        }

        public List<Entry> Recent(int limit)
        {
            var list = new List<Entry>();
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "SELECT op_id, shift_id, total, payments, customer_id, customer_name, status, created_at" +
                    " FROM local_sales ORDER BY created_at DESC LIMIT $lim;";
                cmd.Parameters.AddWithValue("$lim", limit);
                using (var r = cmd.ExecuteReader()) while (r.Read()) list.Add(Read(r));
            }
            return list;
        }

        /// <summary>Convert shift sales to the daily-close calculator's records.</summary>
        public List<DailyCloseCalculator.SaleRecord> CloseRecordsFor(string shiftId)
        {
            var records = new List<DailyCloseCalculator.SaleRecord>();
            foreach (var e in SalesForShift(shiftId))
            {
                var rec = new DailyCloseCalculator.SaleRecord
                {
                    Status = e.Status,
                    TotalAmount = e.Total,
                };
                using (var doc = JsonDocument.Parse(e.PaymentsJson))
                {
                    foreach (var p in doc.RootElement.EnumerateArray())
                    {
                        var method = p.TryGetProperty("Method", out var m) ? m.GetString() : null;
                        var amount = p.TryGetProperty("Amount", out var a) ? a.GetDecimal() : 0m;
                        if (method != null) rec.Payments.Add((method, amount));
                    }
                }
                records.Add(rec);
            }
            return records;
        }

        private static Entry Read(SqliteDataReader r)
        {
            return new Entry
            {
                OpId = r.GetString(0),
                ShiftId = r.IsDBNull(1) ? null : r.GetString(1),
                Total = Convert.ToDecimal(r.GetDouble(2)),
                PaymentsJson = r.GetString(3),
                CustomerId = r.IsDBNull(4) ? null : r.GetString(4),
                CustomerName = r.IsDBNull(5) ? null : r.GetString(5),
                Status = r.GetString(6),
                CreatedAt = DateTimeOffset.Parse(r.GetString(7)),
            };
        }

        public void Dispose() { _db.Dispose(); }
    }
}
