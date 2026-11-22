using System;
using System.Collections.Generic;
using System.Linq;
using Delwaqty.Pos.Core.Text;
using Microsoft.Data.Sqlite;

namespace Delwaqty.Pos.Core.Catalog
{
    /// <summary>
    /// Local mirror of a retail merchant's products table for offline lookup.
    /// Same scoring as the drug CatalogCache: exact barcode 1.0, prefix 1.0,
    /// word-boundary 0.9, substring 0.6, trigram word-similarity fallback for
    /// spelling variants.
    /// </summary>
    public sealed class RetailCatalogCache : IDisposable
    {
        private readonly SqliteConnection _db;

        public RetailCatalogCache(string path)
        {
            var cs = new SqliteConnectionStringBuilder { DataSource = path }.ToString();
            _db = new SqliteConnection(cs);
            _db.Open();
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "CREATE TABLE IF NOT EXISTS products (" +
                    " id TEXT PRIMARY KEY, name TEXT, name_ar TEXT, price REAL NOT NULL DEFAULT 0," +
                    " stock REAL, barcode TEXT, search_norm TEXT, updated_at TEXT);" +
                    "CREATE INDEX IF NOT EXISTS products_norm ON products(search_norm);";
                cmd.ExecuteNonQuery();
            }
        }

        public void Upsert(RetailProduct p)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "INSERT OR REPLACE INTO products" +
                    " (id, name, name_ar, price, stock, barcode, search_norm, updated_at)" +
                    " VALUES ($id, $name, $ar, $price, $stock, $bc, $norm, $upd);";
                cmd.Parameters.AddWithValue("$id", p.Id ?? "");
                cmd.Parameters.AddWithValue("$name", (object)p.Name ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$ar", (object)p.NameAr ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$price", p.Price);
                cmd.Parameters.AddWithValue("$stock", p.Stock.HasValue ? (object)p.Stock.Value : DBNull.Value);
                cmd.Parameters.AddWithValue("$bc", (object)p.Barcode ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$norm", p.SearchNorm ?? ArabicNormalizer.Normalize(
                    (p.NameAr ?? "") + " " + (p.Name ?? "")) ?? "");
                cmd.Parameters.AddWithValue("$upd", (object)p.UpdatedAt ?? DBNull.Value);
                cmd.ExecuteNonQuery();
            }
        }

        public sealed class Hit
        {
            public RetailProduct Product;
            public double Score;
        }

        public List<Hit> Search(string query, int limit)
        {
            var hits = new List<Hit>();
            var norm = ArabicNormalizer.Normalize(query);
            var raw = (query ?? "").Trim();
            if (norm == null && raw.Length == 0) return hits;
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "SELECT id, name, name_ar, price, stock, barcode, search_norm, updated_at" +
                    " FROM products" +
                    " WHERE barcode = $raw OR search_norm LIKE '%' || $q || '%'" +
                    " LIMIT 500;";
                cmd.Parameters.AddWithValue("$raw", raw);
                cmd.Parameters.AddWithValue("$q", norm ?? "");
                using (var r = cmd.ExecuteReader())
                {
                    while (r.Read())
                    {
                        var p = Read(r);
                        double score = 0;
                        if (p.Barcode == raw && raw.Length > 0) score = 1.0;
                        else if (p.SearchNorm != null && norm != null)
                        {
                            if (p.SearchNorm.StartsWith(norm, StringComparison.Ordinal)) score = 1.0;
                            else if (p.SearchNorm.Contains(" " + norm)) score = 0.9;
                            else if (p.SearchNorm.Contains(norm)) score = 0.6;
                        }
                        if (score > 0) hits.Add(new Hit { Product = p, Score = score });
                    }
                }
            }
            if (hits.Count < limit && norm != null)
            {
                var seen = new HashSet<string>(hits.Select(h => h.Product.Id ?? ""));
                using (var cmd = _db.CreateCommand())
                {
                    cmd.CommandText =
                        "SELECT id, name, name_ar, price, stock, barcode, search_norm, updated_at" +
                        " FROM products;";
                    using (var r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var p = Read(r);
                            if (seen.Contains(p.Id ?? "") || p.SearchNorm == null) continue;
                            var sim = CatalogCache.WordSimilarity(norm, p.SearchNorm);
                            if (sim >= 0.4) hits.Add(new Hit { Product = p, Score = sim });
                        }
                    }
                }
            }
            hits.Sort((a, b) => b.Score.CompareTo(a.Score));
            if (hits.Count > limit) hits.RemoveRange(limit, hits.Count - limit);
            return hits;
        }

        public RetailProduct ById(string id)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "SELECT id, name, name_ar, price, stock, barcode, search_norm, updated_at" +
                    " FROM products WHERE id = $id;";
                cmd.Parameters.AddWithValue("$id", id ?? "");
                using (var r = cmd.ExecuteReader())
                {
                    return r.Read() ? Read(r) : null;
                }
            }
        }

        public int Count()
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText = "SELECT count(*) FROM products;";
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }

        private static RetailProduct Read(SqliteDataReader r)
        {
            return new RetailProduct
            {
                Id = r.IsDBNull(0) ? null : r.GetString(0),
                Name = r.IsDBNull(1) ? null : r.GetString(1),
                NameAr = r.IsDBNull(2) ? null : r.GetString(2),
                Price = r.IsDBNull(3) ? 0m : Convert.ToDecimal(r.GetDouble(3)),
                Stock = r.IsDBNull(4) ? (decimal?)null : Convert.ToDecimal(r.GetDouble(4)),
                Barcode = r.IsDBNull(5) ? null : r.GetString(5),
                SearchNorm = r.IsDBNull(6) ? null : r.GetString(6),
                UpdatedAt = r.IsDBNull(7) ? null : r.GetString(7),
            };
        }

        public void Dispose() { _db.Dispose(); }
    }
}
