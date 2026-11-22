using System.IO;
using System.Text.Json;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class OutboxTests
    {
        [Fact]
        public void Sale_Op_Emits_Server_Keys()
        {
            var s = new SaleBuilder { CustomerName = "احمد", ShiftId = System.Guid.NewGuid().ToString() };
            s.AddLine(new SaleLine
            {
                ProductId = System.Guid.NewGuid().ToString(),
                Name = "كونتافيفير ن", Qty = 2, UnitPrice = 33,
            });
            s.AddPayment("cash", 66);
            s.Close();
            var op = OutboxPayloads.Sale(s);
            Assert.Equal("sale", op.Type);
            using (var doc = JsonDocument.Parse(op.PayloadJson))
            {
                var p = doc.RootElement;
                Assert.Equal(66m, p.GetProperty("total").GetDecimal());
                Assert.Equal(66m, p.GetProperty("subtotal").GetDecimal());
                var item = p.GetProperty("items")[0];
                Assert.Equal(66m, item.GetProperty("total").GetDecimal());
                Assert.Equal(33m, item.GetProperty("unit_price").GetDecimal());
                Assert.False(item.GetProperty("is_weight_based").GetBoolean());
                Assert.Equal("cash", p.GetProperty("payments")[0].GetProperty("method").GetString());
            }
        }

        [Fact]
        public void Wire_Envelope_Carries_Op_Id_Type_And_Offline_Time()
        {
            var op = OutboxPayloads.StockCount(System.Guid.NewGuid().ToString(), 42, "جرد نوفمبر");
            using (var doc = JsonDocument.Parse(op.ToWireJson()))
            {
                var r = doc.RootElement;
                Assert.Equal(op.OpId, r.GetProperty("op_id").GetString());
                Assert.Equal("stock_count", r.GetProperty("type").GetString());
                Assert.True(r.GetProperty("created_offline_at").GetString().EndsWith("+00"));
                Assert.Equal(42m, r.GetProperty("payload").GetProperty("counted").GetDecimal());
            }
        }

        [Fact]
        public void Store_Roundtrips_And_Idempotent_Enqueue()
        {
            var path = Path.Combine(Path.GetTempPath(), "outbox-test-" + System.Guid.NewGuid() + ".db");
            try
            {
                using (var store = new OutboxStore(path))
                {
                    var op = OutboxPayloads.BulkPricePct(10);
                    store.Enqueue(op);
                    store.Enqueue(op); // same op_id ignored
                    Assert.Equal(1, store.PendingCount());
                    var pending = store.Pending(10);
                    Assert.Single(pending);
                    Assert.Equal(op.OpId, pending[0].OpId);
                    store.MarkSynced(op.OpId);
                    Assert.Equal(0, store.PendingCount());
                }
            }
            finally { File.Delete(path); }
        }
    }
}
