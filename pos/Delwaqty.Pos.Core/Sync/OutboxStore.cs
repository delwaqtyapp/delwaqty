using System;
using System.Collections.Generic;
using Microsoft.Data.Sqlite;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>SQLite-backed outbox. Survives crashes; push is idempotent server-side.</summary>
    public sealed class OutboxStore : IDisposable
    {
        private readonly SqliteConnection _db;

        public OutboxStore(string path)
        {
            var cs = new SqliteConnectionStringBuilder { DataSource = path }.ToString();
            _db = new SqliteConnection(cs);
            _db.Open();
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "CREATE TABLE IF NOT EXISTS outbox (" +
                    " op_id TEXT PRIMARY KEY," +
                    " type TEXT NOT NULL," +
                    " payload TEXT NOT NULL," +
                    " created_offline_at TEXT NOT NULL," +
                    " attempts INTEGER NOT NULL DEFAULT 0," +
                    " synced INTEGER NOT NULL DEFAULT 0);";
                cmd.ExecuteNonQuery();
            }
        }

        public void Enqueue(OutboxOp op)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "INSERT OR IGNORE INTO outbox (op_id, type, payload, created_offline_at, attempts, synced)" +
                    " VALUES ($id, $t, $p, $c, 0, 0);";
                cmd.Parameters.AddWithValue("$id", op.OpId);
                cmd.Parameters.AddWithValue("$t", op.Type);
                cmd.Parameters.AddWithValue("$p", op.PayloadJson);
                cmd.Parameters.AddWithValue("$c", op.CreatedOfflineAt.UtcDateTime.ToString("o"));
                cmd.ExecuteNonQuery();
            }
        }

        public List<OutboxOp> Pending(int limit)
        {
            var list = new List<OutboxOp>();
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "SELECT op_id, type, payload, created_offline_at, attempts FROM outbox" +
                    " WHERE synced = 0 ORDER BY created_offline_at LIMIT $lim;";
                cmd.Parameters.AddWithValue("$lim", limit);
                using (var r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        list.Add(new OutboxOp(r.GetString(1), r.GetString(2))
                        {
                            OpId = r.GetString(0),
                            CreatedOfflineAt = DateTimeOffset.Parse(r.GetString(3)),
                            Attempts = r.GetInt32(4),
                        });
                    }
                }
            }
            return list;
        }

        public void MarkSynced(string opId)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText = "UPDATE outbox SET synced = 1 WHERE op_id = $id;";
                cmd.Parameters.AddWithValue("$id", opId);
                cmd.ExecuteNonQuery();
            }
        }

        public void BumpAttempts(string opId)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText = "UPDATE outbox SET attempts = attempts + 1 WHERE op_id = $id;";
                cmd.Parameters.AddWithValue("$id", opId);
                cmd.ExecuteNonQuery();
            }
        }

        public int PendingCount()
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText = "SELECT count(*) FROM outbox WHERE synced = 0;";
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }

        public void Dispose() { _db.Dispose(); }
    }
}
