using System;
using System.Text.Json;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>Payload shapes the server contract (migrations 340/346/400) reads.</summary>
    public class ContractTests
    {
        [Fact]
        public void SaleVoid_Carries_Sale_Op_Id_So_The_Server_Can_Match()
        {
            var op = OutboxPayloads.SaleVoid("op-123", "غلط في الصنف");
            Assert.Equal("sale_void", op.Type);
            using (var doc = JsonDocument.Parse(op.PayloadJson))
            {
                Assert.Equal("op-123", doc.RootElement.GetProperty("sale_op_id").GetString());
                Assert.Equal("غلط في الصنف", doc.RootElement.GetProperty("reason").GetString());
            }
        }

        [Fact]
        public void DailyClose_Is_A_Local_Rpc_Op_Never_Pushed()
        {
            var op = OutboxPayloads.DailyClose("shift-1", 500m);
            Assert.True(op.IsLocalRpc);
            Assert.Equal("daily_close", op.LocalRpcName);
            using (var doc = JsonDocument.Parse(op.PayloadJson))
            {
                Assert.Equal("shift-1", doc.RootElement.GetProperty("shift_id").GetString());
                Assert.Equal(500m, doc.RootElement.GetProperty("closing_cash").GetDecimal());
            }
        }

        [Fact]
        public void Sync_Ops_Are_Not_Local()
        {
            Assert.False(OutboxPayloads.Customer("a", "b", null).IsLocalRpc);
            Assert.False(OutboxPayloads.ShiftOpen(100).IsLocalRpc);
        }
    }
}
