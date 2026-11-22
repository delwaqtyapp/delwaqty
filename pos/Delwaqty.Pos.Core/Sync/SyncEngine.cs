using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>
    /// Flushes the outbox in batches. Server dedupes on (merchant_id, client_op_id)
    /// and on pos_sales.idempotency_key, so a retried push is safe; a 'duplicate'
    /// result is treated as synced.
    /// </summary>
    public sealed class SyncEngine
    {
        private readonly OutboxStore _store;
        private readonly SyncClient _client;
        private readonly string _merchantId;

        public SyncEngine(OutboxStore store, SyncClient client, string merchantId)
        {
            _store = store; _client = client; _merchantId = merchantId;
        }

        public sealed class FlushResult
        {
            public int Sent;
            public int Synced;
            public int Failed;
            public string Error;
        }

        public async Task<FlushResult> FlushAsync(int batchSize = 50)
        {
            var pending = _store.Pending(batchSize);
            var result = new FlushResult();
            if (pending.Count == 0) return result;
            result.Sent = pending.Count;

            string response;
            try
            {
                var opsJson = "[" + string.Join(",", pending.Select(o => o.ToWireJson())) + "]";
                response = await _client.PushOps(_merchantId, opsJson).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                foreach (var op in pending) _store.BumpAttempts(op.OpId);
                result.Failed = pending.Count;
                result.Error = ex.Message;
                return result;
            }

            var done = new HashSet<string>();
            using (var doc = JsonDocument.Parse(response))
            {
                if (doc.RootElement.TryGetProperty("results", out var results))
                {
                    foreach (var r in results.EnumerateArray())
                    {
                        var ok = r.TryGetProperty("ok", out var okEl) && okEl.GetBoolean();
                        var dup = r.TryGetProperty("duplicate", out var dEl) && dEl.GetBoolean();
                        if (ok || dup)
                        {
                            string id = r.TryGetProperty("op_id", out var idEl) ? idEl.GetString() : null;
                            if (id != null) done.Add(id);
                        }
                    }
                }
            }
            foreach (var op in pending)
            {
                if (done.Contains(op.OpId)) { _store.MarkSynced(op.OpId); result.Synced++; }
                else { _store.BumpAttempts(op.OpId); result.Failed++; }
            }
            return result;
        }
    }
}
