using System;
using Delwaqty.Pos.Core.Sales;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class ReceiptTests
    {
        private static ReceiptBuilder.Context Ctx()
        {
            return new ReceiptBuilder.Context
            {
                StoreName = "صيدلية الشفاء",
                StorePhone = "0123456789",
                StoreAddress = "ميت غمر - دقهلية",
                SaleId = "ab12",
                When = new DateTimeOffset(2026, 11, 23, 10, 30, 0, TimeSpan.Zero),
                IsPharmacy = true,
            };
        }

        [Fact]
        public void Receipt_Shows_Lines_Totals_And_Payments()
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "بنادول اكسترا 24 قرص", Qty = 2, UnitPrice = 45.5m });
            s.AddLine(new SaleLine { Name = "فيتامين سي", Qty = 1, UnitPrice = 30 });
            s.AddPayment("cash", 60);
            s.AddPayment("instapay", 61);
            s.Close();
            var text = ReceiptBuilder.Build(Ctx(), s);
            Assert.Contains("صيدلية الشفاء", text);
            Assert.Contains("بنادول اكسترا 24 قرص", text);
            Assert.Contains("121", text);   // total
            Assert.Contains("نقدي", text);
            Assert.Contains("انستاباي", text);
            Assert.Contains("شكراً", text);
        }

        [Fact]
        public void Deferred_Receipt_Names_The_Customer_And_The_Remainder()
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "انالجين", Qty = 1, UnitPrice = 100 });
            s.AddPayment("cash", 40);
            s.CustomerId = Guid.NewGuid().ToString();
            var ctx = Ctx();
            ctx.CustomerName = "الحاج محمود";
            s.Close();
            var text = ReceiptBuilder.Build(ctx, s);
            Assert.Contains("الحاج محمود", text);
            Assert.Contains("متبقي آجل", text);
            Assert.Contains("60", text);
        }

        [Fact]
        public void Method_Labels_Cover_The_Server_Set()
        {
            foreach (var m in SaleBuilder.AllowedMethods)
                Assert.False(string.IsNullOrWhiteSpace(ReceiptBuilder.MethodLabel(m)));
            Assert.Equal("فودافون كاش", ReceiptBuilder.MethodLabel("vodafone_cash"));
        }

        [Fact]
        public void Pharmacy_Receipt_Adds_The_Dispensing_Footer_Not_Advice()
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "شراب", Qty = 1, UnitPrice = 20 });
            s.AddPayment("cash", 20);
            s.Close();
            var text = ReceiptBuilder.Build(Ctx(), s);
            Assert.Contains("حسب إرشادات الطبيب أو الصيدلي", text);
        }
    }
}
