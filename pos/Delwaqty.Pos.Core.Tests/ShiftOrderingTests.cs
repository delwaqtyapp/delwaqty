using System;
using System.IO;
using System.Linq;
using System.Net.Http;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>
    /// #117: dependency-ordered flush with the explicit local->server shift
    /// map. The regression was: daily_close ran BEFORE the queued sales,
    /// offline sales carried shift_id NULL forever, and only one pending
    /// close could be remembered.
    /// </summary>
    public class ShiftOrderingTests : IDisposable
    {
        private readonly string _path = Path.Combine(Path.GetTempPath(), "ord-" + Guid.NewGuid() + ".db");
        public void Dispose() { if (File.Exists(_path)) File.Delete(_path); }

        private static SaleBuilder MakeSale(string shiftId, decimal price)
        {
            var s = new SaleBuilder { ShiftId = shiftId };
            s.AddLine(new SaleLine { Name = "بنادول", Qty = 1, UnitPrice = price });
            s.AddPayment("cash", price);
            s.Close();
            return s;
        }

        [Fact]
        public async System.Threading.Tasks.Task Offline_Open_Sales_Close_Then_Two_Shifts_Sync_In_Order()
        {
            var openA = OutboxPayloads.ShiftOpen(100m);
            var saleA = OutboxPayloads.Sale(MakeSale(openA.OpId, 66m));
            var closeA = OutboxPayloads.DailyClose(openA.OpId, 500m);
            var openB = OutboxPayloads.ShiftOpen(50m);
            var saleB = OutboxPayloads.Sale(MakeSale(openB.OpId, 33m));
            var closeB = OutboxPayloads.DailyClose(openB.OpId, 300m);

            // Responses in STRICT creation order: openA, saleA, closeA, then B.
            var stub = new StubHandler()
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + openA.OpId + "\",\"ok\":true,\"shift_id\":\"srv-A\"}]}")
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + saleA.OpId + "\",\"ok\":true,\"sale_id\":\"s-1\"}]}")
                .Ok("{\"ok\":true,\"expected_cash\":500}")
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + openB.OpId + "\",\"ok\":true,\"shift_id\":\"srv-B\"}]}")
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + saleB.OpId + "\",\"ok\":true,\"sale_id\":\"s-2\"}]}")
                .Ok("{\"ok\":true,\"expected_cash\":300}");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));

            using (var store = new OutboxStore(_path))
            {
                // Everything happens offline, in real usage order.
                store.Enqueue(openA); store.Enqueue(saleA); store.Enqueue(closeA);
                store.Enqueue(openB); store.Enqueue(saleB); store.Enqueue(closeB);

                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();

                Assert.Equal(6, res.Synced);
                Assert.Equal(0, res.Failed);
                Assert.Equal(0, res.Blocked);
                Assert.Equal(0, store.PendingCount());

                // Both shifts got an explicit local->server mapping.
                Assert.Equal(2, res.ResolvedShifts.Count);
                Assert.Equal("srv-A", store.GetServerId("shift", openA.OpId));
                Assert.Equal("srv-B", store.GetServerId("shift", openB.OpId));

                // #117a: STRICT creation order — openB is never hoisted above
                // closeA, so it can never bind to (or be rejected for) the
                // still-open A on the server.
                Assert.Equal(6, stub.Requests.Count);
                Assert.Contains(openA.OpId, stub.Requests[0].Body);   // open A
                Assert.Contains(saleA.OpId, stub.Requests[1].Body);   // sale A
                Assert.Contains("srv-A", stub.Requests[1].Body);
                Assert.DoesNotContain(openA.OpId, stub.Requests[1].Body);
                Assert.Contains("cashier_daily_close", stub.Requests[2].Url); // close A
                Assert.Contains("srv-A", stub.Requests[2].Body);
                Assert.DoesNotContain(openA.OpId, stub.Requests[2].Body);
                Assert.Contains(openB.OpId, stub.Requests[3].Body);   // open B AFTER close A
                Assert.Contains(saleB.OpId, stub.Requests[4].Body);   // sale B
                Assert.Contains("srv-B", stub.Requests[4].Body);
                Assert.Contains("cashier_daily_close", stub.Requests[5].Url); // close B
                Assert.Contains("srv-B", stub.Requests[5].Body);
                Assert.DoesNotContain(openB.OpId, stub.Requests[5].Body);

                // The persisted payload was rewritten too (restart-safe).
                var leftover = store.Pending(10);
                Assert.Empty(leftover);
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task ShiftOpen_Failure_Blocks_Sales_And_Close_Without_Retries_Burned()
        {
            var openA = OutboxPayloads.ShiftOpen(100m);
            var saleA = OutboxPayloads.Sale(MakeSale(openA.OpId, 66m));
            var closeA = OutboxPayloads.DailyClose(openA.OpId, 500m);

            var stub = new StubHandler(); // no response -> push fails (404)
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));

            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(openA); store.Enqueue(saleA); store.Enqueue(closeA);
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();

                Assert.Equal(0, res.Synced);
                Assert.Equal(1, res.Failed);   // only the shift_open actually failed
                Assert.Equal(2, res.Blocked);  // sale + close wait for the shift
                Assert.Equal(3, store.PendingCount());

                // Blocked ops were NOT attempt-bumped: they are waiting, not failing.
                var pending = store.Pending(10);
                Assert.Equal(0, pending.Single(o => o.OpId == saleA.OpId).Attempts);
                Assert.Equal(0, pending.Single(o => o.OpId == closeA.OpId).Attempts);
                Assert.Equal(1, pending.Single(o => o.OpId == openA.OpId).Attempts);

                // The sale never hit the wire with a null/local shift id.
                Assert.Single(stub.Requests);
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task Sale_With_Server_Shift_Id_Passes_Through()
        {
            var saleOp = OutboxPayloads.Sale(MakeSale("srv-known", 20m));
            var stub = new StubHandler()
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + saleOp.OpId + "\",\"ok\":true}]}");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(saleOp);
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();
                Assert.Equal(1, res.Synced);
                Assert.Equal(0, res.Blocked);
                Assert.Contains("srv-known", stub.Requests[0].Body);
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task Duplicate_ShiftOpen_Without_Id_Stays_Queued()
        {
            // #117b: crash after the server committed the shift_open but
            // before the map was saved — the retry is a duplicate whose
            // result carries NO shift_id. The engine must NEVER adopt the
            // server's currently-open shift (it may be a different one); the
            // op stays queued until the server resolves by client_op_id, and
            // the dependent close blocks.
            var openA = OutboxPayloads.ShiftOpen(100m);
            var saleA = OutboxPayloads.Sale(MakeSale(openA.OpId, 66m));
            var closeA = OutboxPayloads.DailyClose(openA.OpId, 500m);
            var stub = new StubHandler()
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + openA.OpId + "\",\"ok\":true,\"duplicate\":true}]}")
                .Ok("{\"ok\":true,\"open_shift\":{\"id\":\"srv-OTHER\",\"opened_at\":\"2026-11-23 08:00:00+00\",\"opening_float\":100}}");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(openA); store.Enqueue(saleA); store.Enqueue(closeA);
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();

                Assert.Equal(0, res.Synced);
                Assert.Equal(0, res.Failed);
                Assert.Equal(3, res.Blocked);            // open + sale + close
                Assert.Equal(3, store.PendingCount());   // everything queued
                Assert.Null(store.GetServerId("shift", openA.OpId));
                // No arbitrary pull/adoption happened: only the push went out.
                Assert.Single(stub.Requests);
                Assert.DoesNotContain(stub.Requests, r => r.Url.Contains("cashier_sync_pull"));
                // The queued open was not attempt-bumped: it waits, unharmed.
                Assert.Equal(0, store.Pending(10).Single(o => o.OpId == openA.OpId).Attempts);
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task Sale_Http_Failure_Before_Close_Blocks_The_Close()
        {
            // #117c: the sale push fails (HTTP error); the close must NOT run
            // — a shift never closes with a missing sale, and the close stays
            // queued for the next flush even though its shift IS mapped.
            var openA = OutboxPayloads.ShiftOpen(100m);
            var saleA = OutboxPayloads.Sale(MakeSale(openA.OpId, 66m));
            var closeA = OutboxPayloads.DailyClose(openA.OpId, 500m);
            var stub = new StubHandler()
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + openA.OpId + "\",\"ok\":true,\"shift_id\":\"srv-A\"}]}");
            // no response for the sale push -> 404 -> failure
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(openA); store.Enqueue(saleA); store.Enqueue(closeA);
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();

                Assert.Equal(1, res.Synced);  // only the shift_open
                Assert.Equal(1, res.Failed);  // the sale
                Assert.Equal(1, res.Blocked); // the close
                Assert.Equal(2, store.PendingCount());
                // The close never reached the server.
                Assert.DoesNotContain(stub.Requests, r => r.Url.Contains("cashier_daily_close"));

                // Next flush: sale now pushes fine, close follows in the same run.
                stub.Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + saleA.OpId + "\",\"ok\":true,\"sale_id\":\"s-1\"}]}")
                    .Ok("{\"ok\":true,\"expected_cash\":500}");
                var res2 = await engine.FlushAsync();
                Assert.Equal(2, res2.Synced);
                Assert.Equal(0, res2.Blocked);
                Assert.Equal(0, store.PendingCount());
                Assert.Contains("cashier_daily_close", stub.Requests[stub.Requests.Count - 1].Url);
                Assert.Contains("srv-A", stub.Requests[stub.Requests.Count - 1].Body);
            }
        }
    }
}
