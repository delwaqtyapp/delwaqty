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
                StoreName = "ماركت الشفاء",
                StorePhone = "0123456789",
                StoreAddress = "ميت غمر - دقهلية",
                SaleId = "ab12",
                When = new DateTimeOffset(2026, 11, 23, 10, 30, 0, TimeSpan.Zero),
            };
        }

        [Fact]
        public void Receipt_Shows_Lines_Totals_And_Payments()
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "أرز مصري 5 كيلو", Qty = 2, UnitPrice = 45.5m });
            s.AddLine(new SaleLine { Name = "سكر", Qty = 1, UnitPrice = 30 });
            s.AddPayment("cash", 60);
            s.AddPayment("instapay", 61);
            s.Close();
            var text = ReceiptBuilder.Build(Ctx(), s);
            Assert.Contains("ماركت الشفاء", text);
            Assert.Contains("أرز مصري 5 كيلو", text);
            Assert.Contains("121", text);   // total
            Assert.Contains("نقدي", text);
            Assert.Contains("انستاباي", text);
            Assert.Contains("شكراً", text);
        }

        [Fact]
        public void Deferred_Receipt_Names_The_Customer_And_The_Remainder()
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "زيت", Qty = 1, UnitPrice = 100 });
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
    }
}
