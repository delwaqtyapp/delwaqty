using System.IO;
using System.Linq;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class RetailCatalogTests
    {
        private static RetailCatalogCache NewCache(out string path)
        {
            path = Path.Combine(Path.GetTempPath(), "retail-test-" + System.Guid.NewGuid() + ".db");
            var c = new RetailCatalogCache(path);
            c.Upsert(new RetailProduct
            {
                Id = "p1", Name = "Rice 5kg", NameAr = "أرز ٥ كيلو",
                Price = 120, Stock = 40, Barcode = "6220001",
            });
            c.Upsert(new RetailProduct
            {
                Id = "p2", Name = "Sugar 1kg", NameAr = "سكر ١ كيلو",
                Price = 27.5m, Stock = 100,
            });
            c.Upsert(new RetailProduct
            {
                Id = "p3", Name = "Cooking Oil 1L", NameAr = "زيت طعام ١ لتر",
                Price = 85, Stock = 60,
            });
            c.Upsert(new RetailProduct
            {
                Id = "p4", Name = "Dettol Soap", NameAr = "ديتول صابون",
                Price = 32, Stock = 80,
            });
            return c;
        }

        [Fact]
        public void Barcode_Exact_Match_Wins()
        {
            var cache = NewCache(out var path);
            try
            {
                var hits = cache.Search("6220001", 10);
                Assert.NotEmpty(hits);
                Assert.Equal("p1", hits[0].Product.Id);
                Assert.Equal(1.0, hits[0].Score);
            }
            finally { cache.Dispose(); File.Delete(path); }
        }

        [Fact]
        public void Arabic_Alef_Variants_Match()
        {
            var cache = NewCache(out var path);
            try
            {
                // أرز stored with alef-madda; query with plain alef must still hit.
                var hits = cache.Search("ارز", 10);
                Assert.NotEmpty(hits);
                Assert.Equal("p1", hits[0].Product.Id);
            }
            finally { cache.Dispose(); File.Delete(path); }
        }

        [Fact]
        public void Spelling_Variant_Falls_Back_To_Similarity()
        {
            var cache = NewCache(out var path);
            try
            {
                // ديتولل (doubled lam) should still find ديتول via trigram fallback.
                var hits = cache.Search("ديتولل", 10);
                Assert.NotEmpty(hits);
                Assert.Equal("p4", hits[0].Product.Id);
            }
            finally { cache.Dispose(); File.Delete(path); }
        }

        [Fact]
        public void Pull_Applier_Upserts_Products_And_Is_Idempotent()
        {
            var path = Path.Combine(Path.GetTempPath(), "retail-pull-" + System.Guid.NewGuid() + ".db");
            var cache = new RetailCatalogCache(path);
            try
            {
                var payload = "{\"ok\":true,\"server_time\":\"2026-11-22T01:00:00Z\"," +
                    "\"products\":[" +
                    "{\"id\":\"a\",\"name\":\"Tea\",\"name_ar\":\"شاي\",\"price\":40,\"stock\":25,\"barcode\":\"111\",\"updated_at\":\"2026-11-21T00:00:00Z\"}," +
                    "{\"id\":\"b\",\"name\":\"Coffee\",\"name_ar\":\"قهوة\",\"price\":95,\"stock\":10,\"barcode\":null,\"updated_at\":\"2026-11-21T00:00:00Z\"}]," +
                    "\"customers\":[{\"id\":\"c1\",\"name\":\"أم محمد\",\"phone\":\"0100\",\"balance\":150.5}]," +
                    "\"open_shift\":{\"id\":\"s1\",\"opened_at\":\"2026-11-22T00:30:00Z\",\"opening_float\":500}}";

                var first = PullApplier.Apply(payload, cache);
                Assert.Equal(2, first.Products);
                Assert.Equal(1, first.Customers);
                Assert.Equal("s1", first.OpenShiftId);
                Assert.Equal(150.5m, first.CustomerList[0].Balance);
                Assert.Equal(2, cache.Count());

                // Re-apply with a price change: same rows, updated price, no dupes.
                var updated = payload.Replace("\"price\":40", "\"price\":45");
                var second = PullApplier.Apply(updated, cache);
                Assert.Equal(2, second.Products);
                Assert.Equal(2, cache.Count());
                Assert.Equal(45m, cache.ById("a").Price);
            }
            finally { cache.Dispose(); File.Delete(path); }
        }

        [Fact]
        public void Pull_Applier_Tolerates_Empty_Payload()
        {
            var path = Path.Combine(Path.GetTempPath(), "retail-empty-" + System.Guid.NewGuid() + ".db");
            var cache = new RetailCatalogCache(path);
            try
            {
                var s = PullApplier.Apply(
                    "{\"ok\":true,\"server_time\":\"2026-11-22T01:00:00Z\",\"products\":[],\"customers\":[],\"open_shift\":null}",
                    cache);
                Assert.Equal(0, s.Products);
                Assert.Equal(0, s.Customers);
                Assert.Null(s.OpenShiftId);
            }
            finally { cache.Dispose(); File.Delete(path); }
        }
    }
}
