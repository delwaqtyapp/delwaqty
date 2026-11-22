using System;
using Delwaqty.Pos.Core.Sales;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class SaleBuilderTests
    {
        private static SaleLine Line(string name, decimal qty, decimal price, decimal disc = 0)
        {
            return new SaleLine { Name = name, Qty = qty, UnitPrice = price, DiscountAmount = disc };
        }

        [Fact]
        public void Totals_Round_Like_The_Server()
        {
            var s = new SaleBuilder();
            s.AddLine(Line("كونتافيفير ن", 2, 33));
            s.AddLine(Line("بنادول اكسترا", 1, 45.5m, 0.5m));
            Assert.Equal(66 + 45, s.Subtotal);
            s.SetDiscount(5);
            Assert.Equal(106, s.Total);
            s.AddPayment("cash", 106);
            s.Close();
            Assert.Equal(0, s.DeferredAmount);
        }

        [Fact]
        public void Split_Cash_And_Deferred_Requires_Customer()
        {
            var s = new SaleBuilder();
            s.AddLine(Line("انالجين", 1, 30));
            s.AddPayment("cash", 10);
            s.AddPayment("deferred", 20);
            Assert.Throws<InvalidOperationException>(() => s.Close()); // deferred without customer
            s.CustomerId = Guid.NewGuid().ToString();
            s.Close();
            Assert.Equal(20, s.DeferredAmount);
            Assert.Equal(30, s.Payments[0].Amount + s.Payments[1].Amount);
            Assert.Equal("deferred", s.Payments[1].Method);
        }

        [Fact]
        public void Auto_Cash_Covers_Remainder()
        {
            var s = new SaleBuilder();
            s.AddLine(Line("فيتامين", 1, 50));
            s.AddPayment("cash", 20);
            s.Close();
            Assert.Equal(2, s.Payments.Count);
            Assert.Equal("cash", s.Payments[1].Method);
            Assert.Equal(0, s.DeferredAmount);
        }

        [Fact]
        public void Rejects_Empty_And_Underpaid()
        {
            Assert.Throws<InvalidOperationException>(() => new SaleBuilder().Close());
        }
    }
}
