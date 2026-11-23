using System;
using System.Text.Json;
using System.Threading.Tasks;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Core.Catalog
{
    /// <summary>
    /// Downloads the shared MoH-aligned drug catalog (~25k rows) into the
    /// local CatalogCache for offline lookup. drug_catalog is readable by any
    /// authenticated user (policy drug_catalog_read), so the merchant session
    /// is enough. Paged with keyset pagination on id to stay cheap on metered
    /// connections; rows are upserted, so re-runs and resumes are safe.
    /// </summary>
    public sealed class DrugCatalogSync
    {
        public const int PageSize = 1000;
        private const string Columns =
            "id,name_en,name_ar,active_ingredient,manufacturer,official_price_egp,barcode,dosage_form,strength,category,is_active";

        private readonly SyncClient _client;

        public DrugCatalogSync(SyncClient client) { _client = client; }

        public sealed class Result
        {
            public int Rows;
            public int Pages;
            public bool Complete;
            public string LastId;   // resume key
            public string Error;
        }

        /// <summary>
        /// Fetch up to maxPages pages starting after afterId (null = from the
        /// beginning). Returns the last id seen so the caller can resume later.
        /// </summary>
        public Task<Result> DownloadAsync(CatalogCache cache, string afterId, int maxPages)
        {
            return DownloadAsync(cache, afterId, maxPages, PageSize);
        }

        /// <summary>DownloadAsync with an explicit page size (small shops / tests).</summary>
        public async Task<Result> DownloadAsync(CatalogCache cache, string afterId, int maxPages, int pageSize)
        {
            var result = new Result { LastId = afterId, Complete = true };
            for (var page = 0; page < maxPages; page++)
            {
                var query = "drug_catalog?select=" + Columns + "&order=id.asc&limit=" + pageSize;
                if (result.LastId != null) query += "&id=gt." + result.LastId;
                string json;
                try { json = await _client.RestGetAsync(query).ConfigureAwait(false); }
                catch (Exception ex) { result.Complete = false; result.Error = ex.Message; return result; }

                var count = ApplyPage(json, cache, result);
                result.Pages++;
                if (count < pageSize) return result; // last page
            }
            result.Complete = false; // hit the page budget with more likely remaining
            return result;
        }

        private static int ApplyPage(string json, CatalogCache cache, Result result)
        {
            var count = 0;
            using (var doc = JsonDocument.Parse(json))
            {
                if (doc.RootElement.ValueKind != JsonValueKind.Array) return 0;
                foreach (var el in doc.RootElement.EnumerateArray())
                {
                    cache.Upsert(new DrugProduct
                    {
                        Id = Str(el, "id"),
                        NameEn = Str(el, "name_en"),
                        NameAr = Str(el, "name_ar"),
                        ActiveIngredient = Str(el, "active_ingredient"),
                        Manufacturer = Str(el, "manufacturer"),
                        OfficialPriceEgp = Dec(el, "official_price_egp"),
                        Barcode = Str(el, "barcode"),
                        DosageForm = Str(el, "dosage_form"),
                        Strength = Str(el, "strength"),
                        Category = Str(el, "category"),
                        IsActive = !el.TryGetProperty("is_active", out var a) || a.ValueKind != JsonValueKind.False,
                    });
                    result.Rows++;
                    result.LastId = Str(el, "id");
                    count++;
                }
            }
            return count;
        }

        private static string Str(JsonElement el, string name)
        {
            return el.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        }

        private static decimal? Dec(JsonElement el, string name)
        {
            if (!el.TryGetProperty(name, out var v)) return null;
            if (v.ValueKind == JsonValueKind.Number && v.TryGetDecimal(out var d)) return d;
            if (v.ValueKind == JsonValueKind.String && decimal.TryParse(v.GetString(), out var s)) return s;
            return null;
        }
    }
}
