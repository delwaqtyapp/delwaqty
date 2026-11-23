using System.IO;
using System.Net.Http;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class ProductCreatorTests
    {
        [Fact]
        public void Barcode_Canonicalization_Matches_The_Server_Trigger()
        {
            Assert.Null(ProductCreator.CanonicalBarcode("   "));
            Assert.Null(ProductCreator.CanonicalBarcode(null));
            Assert.Equal("622300123", ProductCreator.CanonicalBarcode(" 622300123 \t\r\n"));
        }

        [Fact]
        public async System.Threading.Tasks.Task Create_Posts_And_Caches_The_New_Product()
        {
            var stub = new StubHandler().Ok("[{\"id\":\"p-9\"}]");
            var client = new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub));
            var creator = new ProductCreator(client, "m-1");
            var dbPath = Path.Combine(Path.GetTempPath(), "retail-" + System.Guid.NewGuid() + ".db");
            try
            {
                using (var cache = new RetailCatalogCache(dbPath))
                {
                    var id = await creator.CreateAsync(cache, "Rice 5kg", "ارز ٥ كيلو", 185m, 20, " 6221 ");
                    Assert.Equal("p-9", id);
                    Assert.Contains("\"merchant_id\":\"m-1\"", stub.Requests[0].Body);
                    Assert.Contains("\"barcode\":\"6221\"", stub.Requests[0].Body);
                    var cached = cache.ById("p-9");
                    Assert.NotNull(cached);
                    Assert.Equal(185m, cached.Price);
                    Assert.Equal("6221", cached.Barcode);
                }
            }
            finally { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); File.Delete(dbPath); }
        }

        [Fact]
        public async System.Threading.Tasks.Task Create_Requires_A_Name()
        {
            var creator = new ProductCreator(new SyncClient("https://x", "k"), "m-1");
            await Assert.ThrowsAsync<System.ArgumentException>(
                () => creator.CreateAsync(null, " ", "", 10m, 0, null));
        }
    }
}
