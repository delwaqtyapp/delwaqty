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
}
