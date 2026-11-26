using System;
using System.IO;
using System.Net.Http;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class SyncEngineLocalRpcTests : IDisposable
    {
        private readonly string _path = Path.Combine(Path.GetTempPath(), "outbox-" + Guid.NewGuid() + ".db");
        public void Dispose() { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); if (File.Exists(_path)) File.Delete(_path); }

        [Fact]
        public async System.Threading.Tasks.Task DailyClose_Goes_To_Its_Own_Rpc_Not_SyncPush()
        {
            var stub = new StubHandler().Ok("{\"ok\":true,\"expected_cash\":500}");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(OutboxPayloads.DailyClose("shift-1", 500m));
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();
                Assert.Equal(1, res.Synced);
                Assert.Equal(0, res.Failed);
                Assert.Contains("cashier_daily_close", stub.Requests[0].Url);
                Assert.Contains("shift-1", stub.Requests[0].Body);
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task DailyClose_Server_Refusal_Stays_Pending()
        {
            var stub = new StubHandler().Ok("{\"ok\":false,\"reason\":\"SHIFT_NOT_OPEN\"}");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                var op = OutboxPayloads.DailyClose("shift-x", 100m);
                store.Enqueue(op);
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();
                Assert.Equal(0, res.Synced);
                Assert.Equal(1, res.Failed);
                Assert.Equal("SHIFT_NOT_OPEN", res.Failures[0].Reason);
                Assert.Equal(1, store.PendingCount()); // still queued for retry
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task Push_Counts_Repriced_And_ClientPriced_Lines()
        {
            var saleOpId = Guid.NewGuid().ToString();
            var stub = new StubHandler().Ok(
                "{\"ok\":true,\"results\":[{\"op_id\":\"" + saleOpId + "\",\"ok\":true," +
                "\"sale_id\":\"s-1\",\"total\":66,\"repriced\":1,\"client_priced\":1}]}");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                var s = new SaleBuilder();
                s.AddLine(new SaleLine { Name = "زيت عافية", Qty = 2, UnitPrice = 33 });
                s.AddPayment("cash", 66);
                s.Close();
                var op = OutboxPayloads.Sale(s);
                store.Enqueue(new OutboxOp(op.Type, op.PayloadJson) { OpId = saleOpId });
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();
                Assert.Equal(1, res.Synced);
                Assert.Equal(1, res.RepricedLines);
                Assert.Equal(1, res.ClientPricedLines);
                Assert.Equal(0, store.PendingCount());
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task Network_Failure_Keeps_Everything_Pending()
        {
            var stub = new StubHandler(); // no scripted response -> 404
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(OutboxPayloads.Customer("احمد", "010", null));
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();
                Assert.Equal(1, res.Failed);
                Assert.Equal(1, store.PendingCount());
            }
        }
    }
}
