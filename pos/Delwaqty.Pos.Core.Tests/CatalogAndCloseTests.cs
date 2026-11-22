using System.IO;
using System.Linq;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Close;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class CatalogCacheTests
    {
        private static CatalogCache NewCache(out string path)
        {
            path = Path.Combine(Path.GetTempPath(), "catalog-test-" + System.Guid.NewGuid() + ".db");
            var c = new CatalogCache(path);
            c.Upsert(new DrugProduct
            {
                Id = "1", NameEn = "CONTAFEVER N", NameAr = "كونتافيبر ن",
                ActiveIngredient = "Paracetamol", OfficialPriceEgp = 33, Barcode = "6221001",
            });
            c.Upsert(new DrugProduct
            {
                Id = "2", NameEn = "PANADOL EXTRA", NameAr = "بنادول اكسترا",
                ActiveIngredient = "Paracetamol + Caffeine", OfficialPriceEgp = 45.5m,
            });
            c.Upsert(new DrugProduct
            {
                Id = "3", NameEn = "VOLTAREN", NameAr = "فولتارين", OfficialPriceEgp = 60,
            });
            return c;
        }

        [Fact]
        public void Egyptian_Spelling_Finds_Catalog_Row()
        {
            var cache = NewCache(out var path);
            try
            {
                var hits = cache.Search("كونتافيڤر", 10); // ڤ instead of ف
                Assert.NotEmpty(hits);
                Assert.Equal("1", hits[0].Product.Id);
                Assert.Equal(33, hits[0].Product.OfficialPriceEgp);
            }
            finally { cache.Dispose(); File.Delete(path); }
        }

        [Fact]
        public void Prefix_Beats_Substring()
        {
            var cache = NewCache(out var path);
            try
            {
                var hits = cache.Search("panadol", 10);
                Assert.Equal("2", hits[0].Product.Id);
                Assert.Equal(0.9, hits[0].Score); // word-boundary boost, server parity
            }
            finally { cache.Dispose(); File.Delete(path); }
        }

        [Fact]
        public void Barcode_Exact_Match()
        {
            var cache = NewCache(out var path);
            try
            {
                var hits = cache.Search("6221001", 10);
                Assert.Single(hits);
                Assert.Equal("1", hits[0].Product.Id);
            }
            finally { cache.Dispose(); File.Delete(path); }
        }
    }

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
