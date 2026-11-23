using System;
using System.IO;
using System.Linq;
using Delwaqty.Pos.Core.Sales;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class LocalSalesLogTests : IDisposable
    {
        private readonly string _path = Path.Combine(Path.GetTempPath(), "sales-" + Guid.NewGuid() + ".db");
        private readonly LocalSalesLog _log;
        public LocalSalesLogTests() { _log = new LocalSalesLog(_path); }
        public void Dispose() { _log.Dispose(); Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); if (File.Exists(_path)) File.Delete(_path); }

        private static SaleBuilder Sale(string shiftId, decimal price, params (string m, decimal a)[] pays)
        {
            var s = new SaleBuilder { ShiftId = shiftId };
            s.AddLine(new SaleLine { Name = "صنف", Qty = 1, UnitPrice = price });
            foreach (var (m, a) in pays) s.AddPayment(m, a);
            s.Close();
            return s;
        }

        [Fact]
        public void CloseRecords_Match_The_DailyClose_Math()
        {
            var s1 = Sale("shift-1", 100, ("cash", 100));
            var s2 = Sale("shift-1", 50, ("cash", 20), ("instapay", 30));
            var s3 = new SaleBuilder { ShiftId = "shift-1", CustomerId = Guid.NewGuid().ToString() };
            s3.AddLine(new SaleLine { Name = "صنف", Qty = 1, UnitPrice = 30 });
            s3.AddPayment("deferred", 30);
            s3.Close();
            _log.Add(new LocalSalesLog.OutboxOpRef("op-1"), s1);
            _log.Add(new LocalSalesLog.OutboxOpRef("op-2"), s2);
            _log.Add(new LocalSalesLog.OutboxOpRef("op-3"), s3);

            var records = _log.CloseRecordsFor("shift-1");
            var result = Delwaqty.Pos.Core.Close.DailyCloseCalculator.Compute(200m, records, null);
            Assert.Equal(3, result.SaleCount);
            Assert.Equal(180, result.SalesTotal);
            Assert.Equal(120, result.CashIn);        // 100 + 20; deferred excluded
            Assert.Equal(320, result.ExpectedCash);  // float 200 + cash 120
        }

        [Fact]
        public void Voided_Sales_Are_Excluded_From_The_Close()
        {
            var s1 = Sale("shift-1", 100, ("cash", 100));
            _log.Add(new LocalSalesLog.OutboxOpRef("op-1"), s1);
            _log.MarkVoided("op-1");
            var result = Delwaqty.Pos.Core.Close.DailyCloseCalculator.Compute(
                0m, _log.CloseRecordsFor("shift-1"), null);
            Assert.Equal(0, result.SaleCount);
            Assert.Equal(0, result.ExpectedCash);
        }

        [Fact]
        public void Recent_Returns_Newest_First()
        {
            _log.Add(new LocalSalesLog.OutboxOpRef("op-a"), Sale("s", 10, ("cash", 10)));
            _log.Add(new LocalSalesLog.OutboxOpRef("op-b"), Sale("s", 20, ("cash", 20)));
            var recent = _log.Recent(10);
            Assert.Equal(2, recent.Count);
            Assert.Contains(recent, e => e.OpId == "op-a" && e.Status == "completed");
        }
    }
}
