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
    ///
    /// Two op families:
    /// - sync ops (sale, customer, ...) go through cashier_sync_push.
    /// - local "rpc:" ops (rpc:daily_close) are executed by this client against
    ///   their own RPC; they are never sent to sync_push, which has no such op.
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

        public sealed class OpFailure
        {
            public string OpId;
            public string Type;
            public string Reason;
        }

        public sealed class FlushResult
        {
            public int Sent;
            public int Synced;
            public int Failed;
            public string Error;
            /// <summary>Lines whose price the server replaced with its own (review #26).</summary>
            public int RepricedLines;
            /// <summary>Lines the server could not price (kept the client price; quarantined).</summary>
            public int ClientPricedLines;
            public readonly List<OpFailure> Failures = new List<OpFailure>();
        }

        public async Task<FlushResult> FlushAsync(int batchSize = 50)
        {
            var pending = _store.Pending(batchSize);
            var result = new FlushResult();
            if (pending.Count == 0) return result;
            result.Sent = pending.Count;

            var local = pending.Where(o => o.IsLocalRpc).ToList();
            var pushable = pending.Where(o => !o.IsLocalRpc).ToList();

            foreach (var op in local) await FlushLocalRpc(op, result).ConfigureAwait(false);
            if (pushable.Count > 0) await FlushPushOps(pushable, result).ConfigureAwait(false);
            return result;
        }

        private async Task FlushLocalRpc(OutboxOp op, FlushResult result)
        {
            try
            {
                string response;
                if (op.Type == "rpc:daily_close")
                {
                    string shiftId = null;
                    decimal closing = 0;
                    using (var doc = JsonDocument.Parse(op.PayloadJson))
                    {
                        if (doc.RootElement.TryGetProperty("shift_id", out var s) && s.ValueKind == JsonValueKind.String)
                            shiftId = s.GetString();
                        if (doc.RootElement.TryGetProperty("closing_cash", out var c) && c.ValueKind == JsonValueKind.Number)
                            c.TryGetDecimal(out closing);
                    }
                    response = await _client.DailyClose(_merchantId, shiftId, closing).ConfigureAwait(false);
                    using (var doc = JsonDocument.Parse(response))
                    {
                        if (doc.RootElement.TryGetProperty("ok", out var ok) && ok.GetBoolean())
                        {
                            _store.MarkSynced(op.OpId); result.Synced++;
                            return;
                        }
                        var reason = doc.RootElement.TryGetProperty("reason", out var r) ? r.GetString() : "UNKNOWN";
                        Fail(result, op, reason);
                        return;
                    }
                }
                // Unknown local op: drop it rather than block the queue forever.
                _store.MarkSynced(op.OpId);
                result.Synced++;
            }
            catch (Exception ex)
            {
                Fail(result, op, ex.Message);
            }
        }

        private async Task FlushPushOps(List<OutboxOp> pushable, FlushResult result)
        {
            string response;
            try
            {
                var opsJson = "[" + string.Join(",", pushable.Select(o => o.ToWireJson())) + "]";
                response = await _client.PushOps(_merchantId, opsJson).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                foreach (var op in pushable) _store.BumpAttempts(op.OpId);
                result.Failed += pushable.Count;
                result.Error = ex.Message;
                return;
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
                        var opId = r.TryGetProperty("op_id", out var idEl) ? idEl.GetString() : null;
                        if (ok || dup)
                        {
                            if (opId != null) done.Add(opId);
                            if (r.TryGetProperty("repriced", out var rp) && rp.ValueKind == JsonValueKind.Number)
                                result.RepricedLines += rp.GetInt32();
                            if (r.TryGetProperty("client_priced", out var cp) && cp.ValueKind == JsonValueKind.Number)
                                result.ClientPricedLines += cp.GetInt32();
                        }
                        else if (opId != null)
                        {
                            var reason = r.TryGetProperty("reason", out var rr) ? rr.GetString() : "UNKNOWN";
                            result.Failures.Add(new OpFailure { OpId = opId, Reason = reason });
                        }
                    }
                }
            }
            foreach (var op in pushable)
            {
                if (done.Contains(op.OpId)) { _store.MarkSynced(op.OpId); result.Synced++; }
                else
                {
                    _store.BumpAttempts(op.OpId);
                    result.Failed++;
                    if (!result.Failures.Any(f => f.OpId == op.OpId))
                        result.Failures.Add(new OpFailure { OpId = op.OpId, Type = op.Type, Reason = "NO_RESULT" });
                    else
                        result.Failures.First(f => f.OpId == op.OpId).Type = op.Type;
                }
            }
        }

        private void Fail(FlushResult result, OutboxOp op, string reason)
        {
            _store.BumpAttempts(op.OpId);
            result.Failed++;
            result.Failures.Add(new OpFailure { OpId = op.OpId, Type = op.Type, Reason = reason });
        }
    }
}
