using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Core.Sales
{
    /// <summary>
    /// Retail item entry (إضافة صنف). Products live in the shared products
    /// table; sync_push has no create-product op, so creating is an ONLINE
    /// action over PostgREST (RLS limits writes to the merchant owner — the
    /// signed-in account). Offline selling stays possible through quick
    /// ad-hoc lines (no product id); those sync as client-priced lines.
    /// Barcodes are canonicalized the same way as the server trigger
    /// (migration 400): trim, empty becomes null.
    /// </summary>
    public sealed class ProductCreator
    {
        private readonly SyncClient _client;
        private readonly string _merchantId;

        public ProductCreator(SyncClient client, string merchantId)
        {
            _client = client;
            _merchantId = merchantId;
        }

        public static string CanonicalBarcode(string barcode)
        {
            var b = (barcode ?? "").Trim(' ', '\t', '\r', '\n');
            return b.Length == 0 ? null : b;
        }

        /// <summary>Create a product and upsert it into the local cache. Returns the new id.</summary>
        public async Task<string> CreateAsync(RetailCatalogCache cache, string name, string nameAr,
            decimal price, int stock, string barcode)
        {
            if (string.IsNullOrWhiteSpace(name) && string.IsNullOrWhiteSpace(nameAr))
                throw new ArgumentException("name required");
            if (price < 0) throw new ArgumentOutOfRangeException("price");
            var body = JsonSerializer.Serialize(new Dictionary<string, object>
            {
                ["merchant_id"] = _merchantId,
                ["name"] = string.IsNullOrWhiteSpace(name) ? nameAr.Trim() : name.Trim(),
                ["name_ar"] = string.IsNullOrWhiteSpace(nameAr) ? null : nameAr.Trim(),
                ["price"] = price,
                ["stock_quantity"] = stock,
                ["barcode"] = CanonicalBarcode(barcode),
                ["is_available"] = true,
            });
            var json = await _client.RestWriteAsync("POST", "products", body, "return=representation")
                .ConfigureAwait(false);
            string id = null;
            using (var doc = JsonDocument.Parse(json))
            {
                if (doc.RootElement.ValueKind == JsonValueKind.Array && doc.RootElement.GetArrayLength() > 0)
                {
                    var el = doc.RootElement[0];
                    id = el.TryGetProperty("id", out var idEl) ? idEl.GetString() : null;
                }
            }
            if (id != null && cache != null)
            {
                cache.Upsert(new RetailProduct
                {
                    Id = id,
                    Name = string.IsNullOrWhiteSpace(name) ? nameAr.Trim() : name.Trim(),
                    NameAr = nameAr,
                    Price = price,
                    Stock = stock,
                    Barcode = CanonicalBarcode(barcode),
                });
            }
            return id;
        }
    }
}
