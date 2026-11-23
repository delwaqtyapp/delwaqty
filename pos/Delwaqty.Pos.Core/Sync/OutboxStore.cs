using System;
using System.Collections.Generic;
using Microsoft.Data.Sqlite;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>
    /// SQLite-backed outbox. Survives crashes; push is idempotent server-side.
    /// Can share one connection with the other local stores (PosLocalDb) so a
    /// sale commit is a single transaction (review #120): when Tx is set the
    /// store's commands enlist in it.
    /// </summary>
    public sealed class OutboxStore : IDisposable
    {
        private readonly SqliteConnection _db;
        private readonly bool _ownsConnection;
        internal SqliteTransaction Tx;

        public OutboxStore(string path) : this(Open(path), true) { }

        internal OutboxStore(SqliteConnection db, bool ownsConnection)
        {
            _db = db;
            _ownsConnection = ownsConnection;
            EnsureSchema();
        }

        internal static SqliteConnection Open(string path)
        {
            var cs = new SqliteConnectionStringBuilder { DataSource = path, Pooling = false }.ToString();
            // Pooling disabled: a pooled handle keeps the .db file locked after
            // Dispose on Windows, breaking migrations (File.Move), teardown and any
            // second opener. Stores here are long-lived, so pooling buys nothing.
            var db = new SqliteConnection(cs);
            db.Open();
            return db;
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
                    "CREATE TABLE IF NOT EXISTS outbox (" +
                    " op_id TEXT PRIMARY KEY," +
                    " type TEXT NOT NULL," +
                    " payload TEXT NOT NULL," +
                    " created_offline_at TEXT NOT NULL," +
                    " attempts INTEGER NOT NULL DEFAULT 0," +
                    " synced INTEGER NOT NULL DEFAULT 0);" +
                    "CREATE TABLE IF NOT EXISTS id_map (" +
                    " kind TEXT NOT NULL," +
                    " local_id TEXT NOT NULL," +
                    " server_id TEXT NOT NULL," +
                    " PRIMARY KEY (kind, local_id));";
                cmd.ExecuteNonQuery();
            }
        }

        public void Enqueue(OutboxOp op)
        {
            using (var cmd = Cmd())
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
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "SELECT op_id, type, payload, created_offline_at, attempts FROM outbox" +
                    " WHERE synced = 0 ORDER BY created_offline_at, rowid LIMIT $lim;";
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

        /// <summary>
        /// Rewrite a pending op's payload (review #117: the sync engine swaps a
        /// local shift id for the server id once the shift_open op synced).
        /// Synced rows are never touched.
        /// </summary>
        public void UpdatePayload(string opId, string newPayloadJson)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText = "UPDATE outbox SET payload = $p WHERE op_id = $id AND synced = 0;";
                cmd.Parameters.AddWithValue("$p", newPayloadJson);
                cmd.Parameters.AddWithValue("$id", opId);
                cmd.ExecuteNonQuery();
            }
        }

        public void MarkSynced(string opId)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText = "UPDATE outbox SET synced = 1 WHERE op_id = $id;";
                cmd.Parameters.AddWithValue("$id", opId);
                cmd.ExecuteNonQuery();
            }
        }

        /// <summary>
        /// Put a prematurely-marked op back on the pending queue WITHOUT an
        /// attempt bump (review #117b: a duplicate shift_open whose result
        /// carried no server id stays queued until the server can resolve it
        /// by client_op_id — it is waiting, not failing).
        /// </summary>
        public void MarkUnsynced(string opId)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText = "UPDATE outbox SET synced = 0 WHERE op_id = $id;";
                cmd.Parameters.AddWithValue("$id", opId);
                cmd.ExecuteNonQuery();
            }
        }

        public void BumpAttempts(string opId)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText = "UPDATE outbox SET attempts = attempts + 1 WHERE op_id = $id;";
                cmd.Parameters.AddWithValue("$id", opId);
                cmd.ExecuteNonQuery();
            }
        }

        public int PendingCount()
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText = "SELECT count(*) FROM outbox WHERE synced = 0;";
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }

        // ---- local->server id map (review #117 shift ids; also usable for
        // customers once the server resolves client ids) ----

        public void SetServerId(string kind, string localId, string serverId)
        {
            using (var cmd = Cmd())
            {
                cmd.CommandText =
                    "INSERT INTO id_map (kind, local_id, server_id) VALUES ($k, $l, $s)" +
                    " ON CONFLICT (kind, local_id) DO UPDATE SET server_id = $s;";
                cmd.Parameters.AddWithValue("$k", kind);
                cmd.Parameters.AddWithValue("$l", localId);
                cmd.Parameters.AddWithValue("$s", serverId);
                cmd.ExecuteNonQuery();
            }
        }

        public string GetServerId(string kind, string localId)
        {
            if (localId == null) return null;
            using (var cmd = Cmd())
            {
                cmd.CommandText = "SELECT server_id FROM id_map WHERE kind = $k AND local_id = $l;";
                cmd.Parameters.AddWithValue("$k", kind);
                cmd.Parameters.AddWithValue("$l", localId);
                var v = cmd.ExecuteScalar();
                return v == null || v == DBNull.Value ? null : (string)v;
            }
        }

        public void Dispose() { if (_ownsConnection) _db.Dispose(); }
    }
}
