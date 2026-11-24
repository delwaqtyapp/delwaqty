using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace Delwaqty.Pos.Core.Text
{
    /// <summary>
    /// Mirrors the server-side cashier_normalize_text() exactly (migrations 337/338):
    /// lower(), Arabic variant folding, diacritic/tatweel runs and whitespace runs
    /// collapsed to one space, trimmed, empty becomes null.
    /// </summary>
    public static class ArabicNormalizer
    {
        private static readonly Regex Runs =
            new Regex("[\\u0640\\u064B-\\u0652\\u0670]+|\\s+", RegexOptions.Compiled);

        public static string Normalize(string input)
        {
            if (string.IsNullOrWhiteSpace(input)) return null;
            var s = input.ToLowerInvariant();
            var sb = new StringBuilder(s.Length);
            foreach (var c in s)
            {
                switch (c)
                {
                    case 'أ': case 'إ': case 'آ': case 'ٱ': sb.Append('ا'); break;
                    case 'ى': sb.Append('ي'); break;
                    case 'ة': sb.Append('ه'); break;
                    case 'ئ': sb.Append('ي'); break;
                    case 'ؤ': sb.Append('و'); break;
                    case 'ڤ': sb.Append('ف'); break;
                    case 'پ': sb.Append('ب'); break;
                    case 'گ': sb.Append('ك'); break;
                    case 'چ': sb.Append('ج'); break;
                    case ' ': sb.Append(' '); break;
                    default: sb.Append(c); break;
                }
            }
            var collapsed = Runs.Replace(sb.ToString(), " ").Trim();
            return collapsed.Length == 0 ? null : collapsed;
        }
    }

    /// <summary>Fuzzy text similarity for catalog search scoring.</summary>
    public static class TextSimilarity
    {
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
    }
}
