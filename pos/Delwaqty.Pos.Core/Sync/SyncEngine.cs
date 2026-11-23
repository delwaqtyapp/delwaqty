using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>
    /// Flushes the outbox in dependency order (review #117).
    ///
    /// Server dedupes on (merchant_id, client_op_id) and on
    /// pos_sales.idempotency_key, so a retried push is safe; a 'duplicate'
    /// result is treated as synced.
    ///
    /// Ordering rules:
    /// 1. Pending shift_open ops are pushed FIRST, one at a time in creation
    ///    order, and each server shift id is recorded in the explicit
    ///    local->server shift map (outbox id_map). The push result carries
    ///    'shift_id'; a duplicate (id empty) falls back to one pull.
    /// 2. A sale whose payload shift_id is a known local shift id is
    ///    rewritten to the mapped server id (and persisted via UpdatePayload)
    ///    BEFORE it is pushed — sales never again reach the server with a
    ///    null shift id just because they were made offline.
    /// 3. rpc:daily_close resolves its shift id through the same map and runs
    ///    only after every op enqueued before it was processed, so close
    ///    never outruns the shift's own sales.
    /// 4. An op whose dependency did not sync (shift_open/customer failed or
    ///    is unmapped) is BLOCKED: left pending without bumping attempts, to
    ///    be retried once the dependency lands.
    ///
    /// Two op families:
    /// - sync ops (sale, customer, ...) go through cashier_sync_push.
    /// - local "rpc:" ops (rpc:daily_close) are executed by this client
    ///   against their own RPC; never sent to sync_push.
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
            /// <summary>Ops left pending because a dependency has not synced yet.</summary>
            public int Blocked;
            public string Error;
            /// <summary>Lines whose price the server replaced with its own (review #26).</summary>
            public int RepricedLines;
            /// <summary>Lines the server could not price (kept the client price; quarantined).</summary>
            public int ClientPricedLines;
            public readonly List<OpFailure> Failures = new List<OpFailure>();
            /// <summary>(local id, server id) pairs adopted this flush — the UI
            /// remaps its sales journal from these.</summary>
            public readonly List<KeyValuePair<string, string>> ResolvedShifts =
                new List<KeyValuePair<string, string>>();
        }

        public async Task<FlushResult> FlushAsync(int batchSize = 50)
        {
            var result = new FlushResult();
            var pending = _store.Pending(500);
            if (pending.Count == 0) return result;
            result.Sent = pending.Count;

            var failedIds = new HashSet<string>();
            // Shift opens that synced without yielding a server id, or failed:
            // their sales and closes must block, never push with a local id.
            var unresolvedShifts = new HashSet<string>();

            // Phase 0: shift_open ops first, so the shift map exists before
            // any sale or close that references them.
            foreach (var op in pending.Where(o => o.Type == "shift_open"))
            {
                if (_store.GetServerId("shift", op.OpId) != null) continue; // already mapped
                var pushed = await PushBatch(new List<OutboxOp> { op }, result, failedIds).ConfigureAwait(false);
                if (!pushed) { unresolvedShifts.Add(op.OpId); continue; }
                var serverId = _store.GetServerId("shift", op.OpId);
                if (serverId == null)
                {
                    // Duplicate-without-id edge (crash between push and
                    // MarkSynced): adopt from the server's open shift.
                    serverId = await PullOpenShiftId().ConfigureAwait(false);
                    if (serverId != null) _store.SetServerId("shift", op.OpId, serverId);
                }
                if (serverId != null)
                    result.ResolvedShifts.Add(new KeyValuePair<string, string>(op.OpId, serverId));
                else
                    unresolvedShifts.Add(op.OpId);
            }

            // Phase 1: everything else, in creation order.
            var pendingCustomerIds = new HashSet<string>(
                pending.Where(o => o.Type == "customer").Select(o => o.OpId));
            var pushable = new List<OutboxOp>();
            foreach (var op in pending)
            {
                if (op.Type == "shift_open") continue; // phase 0 handled it
                if (op.IsLocalRpc)
                {
                    await DrainPush(pushable, result, failedIds).ConfigureAwait(false);
                    await FlushLocalRpc(op, result, failedIds, unresolvedShifts).ConfigureAwait(false);
                    continue;
                }
                if (op.Type == "sale" || op.Type == "debt_payment")
                {
                    // Know the customer's fate before deciding: drain the
                    // batch so its push result is in, then block if it failed.
                    if (DependsOnPendingCustomer(op, pendingCustomerIds, failedIds))
                    {
                        await DrainPush(pushable, result, failedIds).ConfigureAwait(false);
                        if (CustomerDependencyFailed(op, failedIds))
                        {
                            result.Blocked++;
                            continue;
                        }
                    }
                    if (op.Type == "sale" &&
                        PrepareSale(op, unresolvedShifts, failedIds) == DepAction.Block)
                    {
                        result.Blocked++;
                        continue;
                    }
                }
                pushable.Add(op);
                if (pushable.Count >= batchSize)
                    await DrainPush(pushable, result, failedIds).ConfigureAwait(false);
            }
            await DrainPush(pushable, result, failedIds).ConfigureAwait(false);
            return result;
        }

        private static bool DependsOnPendingCustomer(OutboxOp op, HashSet<string> pendingCustomerIds,
            HashSet<string> failedIds)
        {
            if (pendingCustomerIds.Count == 0) return false;
            using (var doc = JsonDocument.Parse(op.PayloadJson))
            {
                if (doc.RootElement.TryGetProperty("customer_id", out var c) &&
                    c.ValueKind == JsonValueKind.String)
                {
                    var id = c.GetString();
                    return pendingCustomerIds.Contains(id) && !failedIds.Contains(id);
                }
            }
            return false;
        }

        private enum DepAction { Ready, Block }

        /// <summary>
        /// Rewrite a sale's shift_id from the local id to the mapped server id
        /// before pushing; block when the shift has not synced (#117) or its
        /// deferred-payment customer op failed this flush (#118).
        /// </summary>
        private DepAction PrepareSale(OutboxOp op, HashSet<string> unresolvedShifts,
            HashSet<string> failedIds)
        {
            string shiftId = null;
            using (var doc = JsonDocument.Parse(op.PayloadJson))
            {
                if (doc.RootElement.TryGetProperty("shift_id", out var s) && s.ValueKind == JsonValueKind.String)
                    shiftId = s.GetString();
            }
            if (!string.IsNullOrEmpty(shiftId))
            {
                var mapped = _store.GetServerId("shift", shiftId);
                if (mapped != null)
                {
                    op.PayloadJson = SetJsonField(op.PayloadJson, "shift_id", mapped);
                    _store.UpdatePayload(op.OpId, op.PayloadJson);
                }
                else if (unresolvedShifts.Contains(shiftId) || failedIds.Contains(shiftId))
                {
                    // The shift_open exists locally but never synced: pushing
                    // now would strand the sale with a bogus/null shift.
                    return DepAction.Block;
                }
                // Otherwise: already a server shift id (sale made online) — pass through.
            }
            return CustomerDependencyFailed(op, failedIds) ? DepAction.Block : DepAction.Ready;
        }

        /// <summary>
        /// #118: a deferred sale / debt payment references the customer by the
        /// customer op's stable client id; when that op failed this flush the
        /// dependent op waits for the next one.
        /// </summary>
        private static bool CustomerDependencyFailed(OutboxOp op, HashSet<string> failedIds)
        {
            if (failedIds.Count == 0) return false;
            using (var doc = JsonDocument.Parse(op.PayloadJson))
            {
                if (doc.RootElement.TryGetProperty("customer_id", out var c) &&
                    c.ValueKind == JsonValueKind.String)
                    return failedIds.Contains(c.GetString());
            }
            return false;
        }

        private static string SetJsonField(string json, string field, string value)
        {
            using (var doc = JsonDocument.Parse(json))
            {
                var dict = new Dictionary<string, JsonElement>();
                foreach (var p in doc.RootElement.EnumerateObject()) dict[p.Name] = p.Value.Clone();
                using (var ms = new System.IO.MemoryStream())
                {
                    using (var w = new Utf8JsonWriter(ms))
                    {
                        w.WriteStartObject();
                        foreach (var kv in dict)
                        {
                            if (kv.Key == field) { w.WriteString(field, value); continue; }
                            w.WritePropertyName(kv.Key);
                            kv.Value.WriteTo(w);
                        }
                        if (!dict.ContainsKey(field)) w.WriteString(field, value);
                        w.WriteEndObject();
                    }
                    return System.Text.Encoding.UTF8.GetString(ms.ToArray());
                }
            }
        }

        private async Task<string> PullOpenShiftId()
        {
            try
            {
                var pull = await _client.Pull(_merchantId, null).ConfigureAwait(false);
                using (var doc = JsonDocument.Parse(pull))
                {
                    if (doc.RootElement.TryGetProperty("open_shift", out var shift) &&
                        shift.ValueKind == JsonValueKind.Object &&
                        shift.TryGetProperty("id", out var id) && id.ValueKind == JsonValueKind.String)
                        return id.GetString();
                }
            }
            catch { /* pull is a best-effort fallback */ }
            return null;
        }

        private async Task DrainPush(List<OutboxOp> batch, FlushResult result, HashSet<string> failedIds)
        {
            if (batch.Count == 0) return;
            var copy = batch.ToList();
            batch.Clear();
            await PushBatch(copy, result, failedIds).ConfigureAwait(false);
        }

        /// <summary>Push one batch; returns true when every op in it synced.</summary>
        private async Task<bool> PushBatch(List<OutboxOp> pushable, FlushResult result, HashSet<string> failedIds)
        {
            string response;
            try
            {
                var opsJson = "[" + string.Join(",", pushable.Select(o => o.ToWireJson())) + "]";
                response = await _client.PushOps(_merchantId, opsJson).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                foreach (var op in pushable) { _store.BumpAttempts(op.OpId); failedIds.Add(op.OpId); }
                result.Failed += pushable.Count;
                result.Error = ex.Message;
                return false;
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
                            // shift_open results carry the server shift id
                            // (migration 340) — feed the explicit shift map.
                            if (opId != null &&
                                r.TryGetProperty("shift_id", out var sid) &&
                                sid.ValueKind == JsonValueKind.String)
                            {
                                _store.SetServerId("shift", opId, sid.GetString());
                            }
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
                    failedIds.Add(op.OpId);
                    result.Failed++;
                    if (!result.Failures.Any(f => f.OpId == op.OpId))
                        result.Failures.Add(new OpFailure { OpId = op.OpId, Type = op.Type, Reason = "NO_RESULT" });
                    else
                        result.Failures.First(f => f.OpId == op.OpId).Type = op.Type;
                }
            }
            return pushable.All(o => done.Contains(o.OpId));
        }

        private async Task FlushLocalRpc(OutboxOp op, FlushResult result,
            HashSet<string> failedIds, HashSet<string> unresolvedShifts)
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
                    // #117: resolve a local shift id through the map; block the
                    // close when the shift never got a server id — closing by
                    // local id would fail server-side or close the wrong shift.
                    if (shiftId != null)
                    {
                        var mapped = _store.GetServerId("shift", shiftId);
                        if (mapped != null) shiftId = mapped;
                        else if (unresolvedShifts.Contains(shiftId) || failedIds.Contains(shiftId))
                        {
                            result.Blocked++;
                            return;
                        }
                        // Unmapped and not a known local op: already a server id
                        // (shift opened online) — pass through.
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
                        failedIds.Add(op.OpId);
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
                failedIds.Add(op.OpId);
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
