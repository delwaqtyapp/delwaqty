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
    /// #118: a deferred (آجل) sale to a brand-new offline customer used to be
    /// impossible — the sale had no CustomerId so Close() threw. The client
    /// now assigns a stable id (the customer op's own id) at sale time; the
    /// server resolves it via pos_customers.client_op_id (builder migration
    /// reported separately).
    /// </summary>
    public class CustomerLinkTests : IDisposable
    {
        private readonly string _path = Path.Combine(Path.GetTempPath(), "cust-" + Guid.NewGuid() + ".db");
        public void Dispose() { if (File.Exists(_path)) File.Delete(_path); }

        [Fact]
        public void New_Customer_Gets_Stable_Id_And_Deferred_Close_Succeeds()
        {
            var clientCustomerId = Guid.NewGuid().ToString();
            var customerOp = OutboxPayloads.Customer("احمد", "010", null, clientCustomerId);
            Assert.Equal(clientCustomerId, customerOp.OpId);

            var sale = new SaleBuilder { CustomerId = customerOp.OpId, CustomerName = "احمد" };
            sale.AddLine(new SaleLine { Name = "كونتافيفير", Qty = 2, UnitPrice = 33 });
            sale.AddPayment("cash", 16);
            sale.Close(); // must NOT throw anymore: CustomerId is set
            Assert.Equal(50m, sale.DeferredAmount);
            Assert.Contains(sale.Payments, p => p.Method == "deferred" && p.Amount == 50m);

            var saleOp = OutboxPayloads.Sale(sale);
            using (var doc = System.Text.Json.JsonDocument.Parse(saleOp.PayloadJson))
            {
                Assert.Equal(clientCustomerId, doc.RootElement.GetProperty("customer_id").GetString());
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task Customer_Op_Failure_Blocks_The_Dependent_Sale()
        {
            var cust = OutboxPayloads.Customer("احمد", "010", null);
            var sale = new SaleBuilder { CustomerId = cust.OpId, CustomerName = "احمد" };
            sale.AddLine(new SaleLine { Name = "بنادول", Qty = 1, UnitPrice = 20 });
            sale.AddPayment("deferred", 20);
            sale.Close();
            var saleOp = OutboxPayloads.Sale(sale);

            var stub = new StubHandler(); // 404 -> every push fails
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                // First cycle: the customer op fails on its own.
                store.Enqueue(cust);
                var engine = new SyncEngine(store, client, "m-1");
                var res1 = await engine.FlushAsync();
                Assert.Equal(1, res1.Failed);

                // Second cycle: the dependent sale must BLOCK, not hit the
                // wire (it would fail server-side on the unresolved customer).
                store.Enqueue(saleOp);
                var before = stub.Requests.Count;
                var res2 = await engine.FlushAsync();
                Assert.Equal(1, res2.Failed);  // the customer retry
                Assert.Equal(1, res2.Blocked); // the sale waits
                Assert.Equal(2, store.PendingCount());
                foreach (var req in stub.Requests.Skip(before))
                    Assert.DoesNotContain(saleOp.OpId, req.Body);
                // Blocked, not failed: no attempt burned on the sale.
                Assert.Equal(0, store.Pending(10).Single(o => o.OpId == saleOp.OpId).Attempts);
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task Customer_Syncs_Before_The_Dependent_Sale_Is_Sent()
        {
            var cust = OutboxPayloads.Customer("احمد", "010", null);
            var sale = new SaleBuilder { CustomerId = cust.OpId, CustomerName = "احمد" };
            sale.AddLine(new SaleLine { Name = "بنادول", Qty = 1, UnitPrice = 20 });
            sale.AddPayment("deferred", 20);
            sale.Close();
            var saleOp = OutboxPayloads.Sale(sale);

            var stub = new StubHandler()
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + cust.OpId + "\",\"ok\":true}]}")
                .Ok("{\"ok\":true,\"results\":[{\"op_id\":\"" + saleOp.OpId + "\",\"ok\":true,\"sale_id\":\"s-1\"}]}");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(cust);
                store.Enqueue(saleOp);
                var engine = new SyncEngine(store, client, "m-1");
                var res = await engine.FlushAsync();
                Assert.Equal(2, res.Synced);
                // The customer was pushed and synced BEFORE the sale left the
                // device, so the server always knows the client customer id.
                Assert.Equal(2, stub.Requests.Count);
                Assert.Contains(cust.OpId, stub.Requests[0].Body);
                Assert.DoesNotContain(saleOp.OpId, stub.Requests[0].Body);
                Assert.Contains(saleOp.OpId, stub.Requests[1].Body);
            }
        }

        [Fact]
        public async System.Threading.Tasks.Task Debt_Payment_Blocks_On_Failed_Customer_Op()
        {
            var cust = OutboxPayloads.Customer("احمد", "010", null);
            var pay = OutboxPayloads.DebtPayment(cust.OpId, 30m, null);
            var stub = new StubHandler(); // 404 -> customer op fails
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            using (var store = new OutboxStore(_path))
            {
                store.Enqueue(cust);
                var engine = new SyncEngine(store, client, "m-1");
                Assert.Equal(1, (await engine.FlushAsync()).Failed);
                store.Enqueue(pay);
                var res = await engine.FlushAsync();
                Assert.Equal(1, res.Failed);
                Assert.Equal(1, res.Blocked);
                Assert.Equal(2, store.PendingCount());
            }
        }
    }
}
