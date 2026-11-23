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

            var stub = new StubHandler()
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + openA.OpId + "\",\"ok\":true,\"shift_id\":\"srv-A\"}]}")
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + openB.OpId + "\",\"ok\":true,\"shift_id\":\"srv-B\"}]}")
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + saleA.OpId + "\",\"ok\":true,\"sale_id\":\"s-1\"}]}")
                .Ok("{\"ok\":true,\"expected_cash\":500}")
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

                // Order: shift opens first (one batch each), then each shift's
                // sales, and a close only after its own sales were pushed.
                Assert.Equal(6, stub.Requests.Count);
                Assert.Contains(openA.OpId, stub.Requests[0].Body);
                Assert.Contains(openB.OpId, stub.Requests[1].Body);

                // The sales reached the server with SERVER shift ids, not null.
                Assert.Contains(saleA.OpId, stub.Requests[2].Body);
                Assert.Contains("srv-A", stub.Requests[2].Body);
                Assert.DoesNotContain(openA.OpId, stub.Requests[2].Body);
                Assert.Contains("cashier_daily_close", stub.Requests[3].Url);
                Assert.Contains("srv-A", stub.Requests[3].Body);
                Assert.DoesNotContain(openA.OpId, stub.Requests[3].Body);

                Assert.Contains(saleB.OpId, stub.Requests[4].Body);
                Assert.Contains("srv-B", stub.Requests[4].Body);
                Assert.Contains("cashier_daily_close", stub.Requests[5].Url);
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
        public async System.Threading.Tasks.Task Duplicate_ShiftOpen_Recovers_Id_From_Pull()
        {
            // Crash between push and MarkSynced: the retry is a duplicate and
            // the result has no shift_id; the engine falls back to one pull.
            var openA = OutboxPayloads.ShiftOpen(100m);
            var closeA = OutboxPayloads.DailyClose(openA.OpId, 500m);
            var stub = new StubHandler()
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + openA.OpId + "\",\"ok\":true,\"duplicate\":true}]}")
                .Ok("{\"ok\":true,\"open_shift\":{\"id\":\"srv-A\",\"opened_at\":\"2026-11-23 08:00:00+00\",\"opening_float\":100}}")
                .Ok("{\"ok\":true,\"expected_cash\":500}");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(openA); store.Enqueue(closeA);
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();
                Assert.Equal(2, res.Synced);
                Assert.Equal(0, res.Blocked);
                Assert.Equal("srv-A", store.GetServerId("shift", openA.OpId));
                Assert.Contains("cashier_daily_close", stub.Requests[2].Url);
                Assert.Contains("srv-A", stub.Requests[2].Body);
            }
        }
    }
}
