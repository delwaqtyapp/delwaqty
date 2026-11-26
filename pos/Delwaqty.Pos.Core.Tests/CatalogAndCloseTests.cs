using Delwaqty.Pos.Core.Close;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class DailyCloseTests
    {
        [Fact]
        public void Expected_Cash_Matches_Server_Formula()
        {
            var sales = new[]
            {
                new DailyCloseCalculator.SaleRecord
                {
                    Status = "completed", TotalAmount = 106,
                    Payments = { ("cash", 106m) },
                },
                new DailyCloseCalculator.SaleRecord
                {
                    Status = "completed", TotalAmount = 30,
                    Payments = { ("cash", 10m), ("deferred", 20m) },
                },
                new DailyCloseCalculator.SaleRecord
                {
                    Status = "completed", TotalAmount = 124, PaymentMethod = "cash", // web POS sale, no rows
                },
                new DailyCloseCalculator.SaleRecord { Status = "voided", TotalAmount = 999 },
            };
            var r = DailyCloseCalculator.Compute(50, sales, 290);
            Assert.Equal(260, r.SalesTotal);
            Assert.Equal(3, r.SaleCount);
            Assert.Equal(240, r.CashIn);
            Assert.Equal(290, r.ExpectedCash);
            Assert.Equal(0, r.Difference);
        }
    }
}
