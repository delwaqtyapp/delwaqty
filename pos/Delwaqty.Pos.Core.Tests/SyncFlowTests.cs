using System;
using System.IO;
using System.Net.Http;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class DrugCatalogSyncTests : IDisposable
    {
        private readonly string _path = Path.Combine(Path.GetTempPath(), "cat-" + Guid.NewGuid() + ".db");
        public void Dispose() { if (File.Exists(_path)) File.Delete(_path); }

        [Fact]
        public async System.Threading.Tasks.Task Downloads_Pages_Until_Short_Page()
        {
            var page1 = "[" +
                "{\"id\":\"d-1\",\"name_en\":\"PANADOL EXTRA\",\"name_ar\":\"بنادول اكسترا\"," +
                "\"active_ingredient\":\"Paracetamol\",\"official_price_egp\":45.5,\"barcode\":\"6221\"," +
                "\"is_active\":true}," +
                "{\"id\":\"d-2\",\"name_en\":\"ANTINAL\",\"name_ar\":\"انتينال\",\"is_active\":true}]";
            var page2 = "[{\"id\":\"d-3\",\"name_en\":\"OLD\",\"is_active\":false}]";
            var stub = new StubHandler().Ok(page1).Ok(page2);
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            var syncer = new DrugCatalogSync(client);
            using (var cache = new CatalogCache(_path))
            {
                // Tiny pages (2 rows) so the test exercises pagination.
                var res = await syncer.DownloadAsync(cache, null, 10, 2);
                Assert.True(res.Complete);
                Assert.Equal(3, res.Rows);
                Assert.Equal(2, cache.Count()); // d-3 inactive
                var hits = cache.Search("بنادول", 5);
                Assert.Single(hits);
                Assert.Equal(45.5m, hits[0].Product.OfficialPriceEgp);
            }
            Assert.Contains("order=id.asc", stub.Requests[0].Url);
            Assert.Contains("id=gt.d-2", stub.Requests[1].Url); // keyset pagination
        }
    }

    public class SyncEngineLocalRpcTests : IDisposable
    {
        private readonly string _path = Path.Combine(Path.GetTempPath(), "outbox-" + Guid.NewGuid() + ".db");
        public void Dispose() { if (File.Exists(_path)) File.Delete(_path); }

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
                s.AddLine(new SaleLine { Name = "كونتافيفير", Qty = 2, UnitPrice = 33 });
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
