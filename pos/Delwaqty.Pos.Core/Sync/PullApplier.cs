using System;
using System.Collections.Generic;
using System.Text.Json;
using Delwaqty.Pos.Core.Catalog;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>
    /// Applies a cashier_sync_pull response to the local retail catalog cache.
    /// Re-applying the same payload is idempotent (plain upserts), so a
    /// retried or overlapping pull is safe.
    /// </summary>
    public static class PullApplier
    {
        public sealed class PosCustomer
        {
            public string Id;
            public string Name;
            public string Phone;
            public decimal Balance;
        }

        public sealed class Summary
        {
            public int Products;
            public int Customers;
            public string OpenShiftId;
            public string ServerTime;
            public readonly List<PosCustomer> CustomerList = new List<PosCustomer>();
        }

        public static Summary Apply(string pullJson, RetailCatalogCache cache)
        {
            var summary = new Summary();
            using (var doc = JsonDocument.Parse(pullJson))
            {
                var root = doc.RootElement;
                if (root.TryGetProperty("server_time", out var st) && st.ValueKind == JsonValueKind.String)
                    summary.ServerTime = st.GetString();

                if (root.TryGetProperty("products", out var products) &&
                    products.ValueKind == JsonValueKind.Array)
                {
                    foreach (var el in products.EnumerateArray())
                    {
                        cache.Upsert(new RetailProduct
                        {
                            Id = Str(el, "id"),
                            Name = Str(el, "name"),
                            NameAr = Str(el, "name_ar"),
                            Price = Dec(el, "price") ?? 0m,
                            Stock = Dec(el, "stock"),
                            Barcode = Str(el, "barcode"),
                            UpdatedAt = Str(el, "updated_at"),
                        });
                        summary.Products++;
                    }
                }

                if (root.TryGetProperty("customers", out var customers) &&
                    customers.ValueKind == JsonValueKind.Array)
                {
                    foreach (var el in customers.EnumerateArray())
                    {
                        summary.CustomerList.Add(new PosCustomer
                        {
                            Id = Str(el, "id"),
                            Name = Str(el, "name"),
                            Phone = Str(el, "phone"),
                            Balance = Dec(el, "balance") ?? 0m,
                        });
                        summary.Customers++;
                    }
                }

                if (root.TryGetProperty("open_shift", out var shift) &&
                    shift.ValueKind == JsonValueKind.Object)
                {
                    summary.OpenShiftId = Str(shift, "id");
                }
            }
            return summary;
        }

        private static string Str(JsonElement el, string name)
        {
            return el.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String
                ? v.GetString()
                : null;
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
