using System.Collections.Generic;
using System.Linq;

namespace Delwaqty.Pos.Core.Close
{
    /// <summary>
    /// Client-side expected-cash math, mirroring cashier_daily_close (migration 340):
    /// opening float + cash payment rows + cash-method sales that have no payment rows.
    /// </summary>
    public static class DailyCloseCalculator
    {
        public sealed class SaleRecord
        {
            public string Status;            // completed | voided ...
            public decimal TotalAmount;
            public string PaymentMethod;     // single-method fallback for web-POS sales
            public List<(string Method, decimal Amount)> Payments = new List<(string, decimal)>();
        }

        public sealed class Result
        {
            public decimal ExpectedCash;
            public decimal SalesTotal;
            public int SaleCount;
            public decimal CashIn;
            public decimal OpeningFloat;
            public decimal? ClosingCash;
            public decimal? Difference { get { return ClosingCash.HasValue ? ClosingCash.Value - ExpectedCash : (decimal?)null; } }
        }

        public static Result Compute(decimal openingFloat, IEnumerable<SaleRecord> sales, decimal? closingCash)
        {
            var completed = (sales ?? Enumerable.Empty<SaleRecord>()).Where(s => s.Status == "completed").ToList();
            decimal cashFromPayments = completed.SelectMany(s => s.Payments)
                .Where(p => p.Method == "cash").Sum(p => p.Amount);
            decimal cashFromSingleMethod = completed
                .Where(s => s.Payments.Count == 0 && s.PaymentMethod == "cash")
                .Sum(s => s.TotalAmount);
            var cashIn = cashFromPayments + cashFromSingleMethod;
            return new Result
            {
                OpeningFloat = openingFloat,
                CashIn = cashIn,
                SalesTotal = completed.Sum(s => s.TotalAmount),
                SaleCount = completed.Count,
                ExpectedCash = openingFloat + cashIn,
                ClosingCash = closingCash,
            };
        }
    }
}
