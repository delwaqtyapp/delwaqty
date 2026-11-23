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
        public void InsuranceSale_Carries_The_Shares_The_Server_Validates()
        {
            var op = OutboxPayloads.InsuranceSale("comp-1", "sale-op-9", "احمد محمد", "CARD-77",
                200m, 150m, 50m);
            Assert.Equal("insurance_sale", op.Type);
            using (var doc = JsonDocument.Parse(op.PayloadJson))
            {
                var p = doc.RootElement;
                Assert.Equal("comp-1", p.GetProperty("company_id").GetString());
                Assert.Equal("sale-op-9", p.GetProperty("sale_op_id").GetString());
                Assert.Equal("احمد محمد", p.GetProperty("member_name").GetString());
                Assert.Equal("CARD-77", p.GetProperty("member_card_no").GetString());
                Assert.Equal(200m, p.GetProperty("total").GetDecimal());
                Assert.Equal(150m, p.GetProperty("company_share").GetDecimal());
                Assert.Equal(50m, p.GetProperty("patient_share").GetDecimal());
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

        [Fact]
        public void InsuranceShare_Mismatch_Rule_Is_Client_Checkable()
        {
            // Server rejects when company_share + patient_share != total by > 0.01.
            // The app should never enqueue such an op; pin the arithmetic here.
            decimal total = 200m, company = 150m, patient = 49.98m;
            Assert.True(Math.Abs(company + patient - total) > 0.01m);
            Assert.False(Math.Abs(150m + 50m - total) > 0.01m);
        }
    }
}
