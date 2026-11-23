using System;
using System.Collections.Generic;
using Delwaqty.Pos.Core.Sales;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>
    /// The pos_sale_payments CHECK constraint (migration 340 + 347) allows
    /// exactly: cash, instapay, vodafone_cash, card, deferred. The client set
    /// must match it one for one; anything else fails the op server-side.
    /// </summary>
    public class PaymentContractTests
    {
        private static readonly HashSet<string> ServerCheck = new HashSet<string>(
            new[] { "cash", "instapay", "vodafone_cash", "card", "deferred" });

        [Fact]
        public void Client_Methods_Match_Server_Check_Exactly()
        {
            Assert.Equal(ServerCheck, new HashSet<string>(SaleBuilder.AllowedMethods));
        }

        [Fact]
        public void All_Server_Methods_Are_Accepted()
        {
            foreach (var m in ServerCheck)
            {
                var s = new SaleBuilder();
                s.AddLine(new SaleLine { Name = "صنف", Qty = 1, UnitPrice = 10 });
                s.AddPayment(m, 10);
                if (m == "deferred") s.CustomerId = Guid.NewGuid().ToString();
                s.Close();
            }
        }

        [Fact]
        public void Wallet_Is_Rejected_Server_Does_Not_Know_It()
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "صنف", Qty = 1, UnitPrice = 10 });
            Assert.Throws<ArgumentException>(() => s.AddPayment("wallet", 10));
        }

        [Fact]
        public void Mixed_Cash_Instapay_Vodafone_Splits_Add_Up()
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "رز", Qty = 2, UnitPrice = 40 });
            s.AddPayment("cash", 30);
            s.AddPayment("instapay", 30);
            s.AddPayment("vodafone_cash", 20);
            s.Close();
            Assert.Equal(80, s.Total);
            Assert.Equal(0, s.DeferredAmount);
            Assert.Equal(3, s.Payments.Count);
        }

        [Fact]
        public void Split_With_Deferred_Part_Needs_Customer_And_Balances()
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "انالجين", Qty = 1, UnitPrice = 100 });
            s.AddPayment("cash", 40);
            s.AddPayment("instapay", 20);
            s.CustomerId = Guid.NewGuid().ToString();
            s.Close(); // remainder auto-deferred
            Assert.Equal(40, s.DeferredAmount);
            Assert.Equal("deferred", s.Payments[2].Method);
        }
    }
}
