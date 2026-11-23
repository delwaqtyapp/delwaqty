using System;
using System.Collections.Generic;
using System.Linq;
using Delwaqty.Pos.Core.Text;
using Microsoft.Data.Sqlite;

namespace Delwaqty.Pos.Core.Catalog
{
    /// <summary>
    /// Local mirror of drug_catalog for offline lookup. Search scoring mirrors
    /// drug_catalog_search's boosts: prefix 1.0, word-boundary 0.9, substring 0.6,
    /// exact barcode 1.0. Trigram similarity is server-side only; offline uses
    /// substring matching, which the normalizer makes tolerant of common Egyptian
    /// spellings (كونتافيڤر, بنادول, ...).
    /// </summary>
    public sealed class CatalogCache : IDisposable
    {
        private readonly SqliteConnection _db;

        public CatalogCache(string path)
        {
            var cs = new SqliteConnectionStringBuilder { DataSource = path, Pooling = false }.ToString();
            // Pooling disabled: a pooled handle keeps the .db file locked after
            // Dispose on Windows, breaking migrations (File.Move), teardown and any
            // second opener. Stores here are long-lived, so pooling buys nothing.
            _db = new SqliteConnection(cs);
            try
            {
            _db.Open();
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "CREATE TABLE IF NOT EXISTS catalog (" +
                    " id TEXT PRIMARY KEY, name_en TEXT, name_ar TEXT, ingredient TEXT," +
                    " manufacturer TEXT, price REAL, barcode TEXT, dosage_form TEXT," +
                    " strength TEXT, category TEXT, search_norm TEXT, is_active INTEGER NOT NULL DEFAULT 1);" +
                    "CREATE INDEX IF NOT EXISTS catalog_norm ON catalog(search_norm);";
                cmd.ExecuteNonQuery();
            }
            }
            catch
            {
                // Corrupt/unreadable db: release the handle so the file is
                // not left locked on Windows.
                _db.Dispose();
                throw;
            }
        }

        public void Upsert(DrugProduct p)
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText =
                    "INSERT OR REPLACE INTO catalog" +
                    " (id, name_en, name_ar, ingredient, manufacturer, price, barcode," +
                    "  dosage_form, strength, category, search_norm, is_active)" +
                    " VALUES ($id, $en, $ar, $ing, $mfr, $pr, $bc, $df, $st, $cat, $norm, $act);";
                cmd.Parameters.AddWithValue("$id", p.Id ?? "");
                cmd.Parameters.AddWithValue("$en", (object)p.NameEn ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$ar", (object)p.NameAr ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$ing", (object)p.ActiveIngredient ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$mfr", (object)p.Manufacturer ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$pr", p.OfficialPriceEgp.HasValue ? (object)p.OfficialPriceEgp.Value : DBNull.Value);
                cmd.Parameters.AddWithValue("$bc", (object)p.Barcode ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$df", (object)p.DosageForm ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$st", (object)p.Strength ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$cat", (object)p.Category ?? DBNull.Value);
                cmd.Parameters.AddWithValue("$norm", p.SearchNorm ?? ArabicNormalizer.Normalize(
                    (p.NameAr ?? "") + " " + (p.NameEn ?? "") + " " +
                    (p.ActiveIngredient ?? "") + " " + (p.Manufacturer ?? "")) ?? "");
                cmd.Parameters.AddWithValue("$act", p.IsActive ? 1 : 0);
                cmd.ExecuteNonQuery();
            }
        }

        public sealed class Hit
        {
            public DrugProduct Product;
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
                    "SELECT id, name_en, name_ar, ingredient, manufacturer, price, barcode," +
                    " dosage_form, strength, category, search_norm FROM catalog" +
                    " WHERE is_active = 1 AND (barcode = $raw OR search_norm LIKE '%' || $q || '%')" +
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
            // Trigram-similarity fallback (mirrors the server's pg_trgm path):
            // catches spelling variants substring matching cannot, e.g.
            // كونتافيڤر (normalized كونتافيفر) finding كونتافيبر.
            if (hits.Count < limit && norm != null)
            {
                var seen = new HashSet<string>(hits.Select(h => h.Product.Id ?? ""));
                using (var cmd = _db.CreateCommand())
                {
                    cmd.CommandText =
                        "SELECT id, name_en, name_ar, ingredient, manufacturer, price, barcode," +
                        " dosage_form, strength, category, search_norm FROM catalog WHERE is_active = 1;";
                    using (var r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var p = Read(r);
                            if (seen.Contains(p.Id ?? "") || p.SearchNorm == null) continue;
                            var sim = WordSimilarity(norm, p.SearchNorm);
                            if (sim >= 0.4) hits.Add(new Hit { Product = p, Score = sim });
                        }
                    }
                }
            }
            hits.Sort((a, b) => b.Score.CompareTo(a.Score));
            if (hits.Count > limit) hits.RemoveRange(limit, hits.Count - limit);
            return hits;
        }

        /// <summary>Best trigram Dice similarity between the query and any single word of the target.</summary>
        internal static double WordSimilarity(string query, string target)
        {
            var q = Trigrams(query);
            if (q.Count == 0) return 0;
            var best = 0.0;
            foreach (var word in target.Split(' '))
            {
                var w = Trigrams(word);
                if (w.Count == 0) continue;
                var shared = 0;
                foreach (var t in q) if (w.Contains(t)) shared++;
                var sim = 2.0 * shared / (q.Count + w.Count);
                if (sim > best) best = sim;
            }
            return best;
        }

        private static HashSet<string> Trigrams(string s)
        {
            var set = new HashSet<string>();
            if (string.IsNullOrEmpty(s)) return set;
            if (s.Length < 3) { set.Add(s); return set; }
            for (var i = 0; i <= s.Length - 3; i++) set.Add(s.Substring(i, 3));
            return set;
        }

        public int Count()
        {
            using (var cmd = _db.CreateCommand())
            {
                cmd.CommandText = "SELECT count(*) FROM catalog WHERE is_active = 1;";
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }

        private static DrugProduct Read(SqliteDataReader r)
        {
            return new DrugProduct
            {
                Id = r.IsDBNull(0) ? null : r.GetString(0),
                NameEn = r.IsDBNull(1) ? null : r.GetString(1),
                NameAr = r.IsDBNull(2) ? null : r.GetString(2),
                ActiveIngredient = r.IsDBNull(3) ? null : r.GetString(3),
                Manufacturer = r.IsDBNull(4) ? null : r.GetString(4),
                OfficialPriceEgp = r.IsDBNull(5) ? (decimal?)null : Convert.ToDecimal(r.GetDouble(5)),
                Barcode = r.IsDBNull(6) ? null : r.GetString(6),
                DosageForm = r.IsDBNull(7) ? null : r.GetString(7),
                Strength = r.IsDBNull(8) ? null : r.GetString(8),
                Category = r.IsDBNull(9) ? null : r.GetString(9),
                SearchNorm = r.IsDBNull(10) ? null : r.GetString(10),
            };
        }

        public void Dispose() { _db.Dispose(); }
    }
}
