using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>
    /// Makes rejected outbox ops visible: a short text for the status area and
    /// an append-only log in the data dir so support can see what the server
    /// said. Never throws (a log failure must not break syncing).
    /// </summary>
    public static class SyncFailureReport
    {
        public const string LogFileName = "sync-failures.log";
        public const int MaxBytes = 256 * 1024;

        /// <summary>One line per failure (at most max), then "+N" when more exist.</summary>
        public static string Summarize(IList<SyncEngine.OpFailure> failures, int max)
        {
            if (failures == null || failures.Count == 0) return "";
            var sb = new StringBuilder();
            var shown = Math.Min(max, failures.Count);
            for (var i = 0; i < shown; i++)
            {
                var f = failures[i];
                if (i > 0) sb.Append('\n');
                sb.Append(string.IsNullOrEmpty(f.Type) ? "op" : f.Type)
                  .Append(": ")
                  .Append(string.IsNullOrEmpty(f.Reason) ? "UNKNOWN" : Trim(f.Reason, 80));
            }
            if (failures.Count > shown) sb.Append("\n+").Append(failures.Count - shown);
            return sb.ToString();
        }

        /// <summary>
        /// Appends each (op id, reason) pair only the first time it is seen in
        /// this session (seen is owned by the caller), so a rejected op that is
        /// retried every minute does not flood the log. When the file passes
        /// MaxBytes it is cut to its newest half, never deleted.
        /// </summary>
        public static void Append(string dir, IList<SyncEngine.OpFailure> failures, DateTimeOffset nowUtc,
            ISet<string> seen)
        {
            if (failures == null || failures.Count == 0 || string.IsNullOrEmpty(dir)) return;
            try
            {
                var sb = new StringBuilder();
                foreach (var f in failures)
                {
                    var reason = Trim(f.Reason ?? "UNKNOWN", 200).Replace('\n', ' ').Replace('\r', ' ');
                    var key = (f.OpId ?? "-") + "|" + reason;
                    if (seen != null && !seen.Add(key)) continue;
                    sb.Append(nowUtc.ToString("o")).Append(' ')
                      .Append(f.OpId ?? "-").Append(' ')
                      .Append(f.Type ?? "-").Append(' ')
                      .Append(reason)
                      .Append('\n');
                }
                if (sb.Length == 0) return;
                var path = Path.Combine(dir, LogFileName);
                if (File.Exists(path) && new FileInfo(path).Length > MaxBytes)
                {
                    var lines = File.ReadAllLines(path, Encoding.UTF8);
                    var keep = new string[lines.Length / 2];
                    Array.Copy(lines, lines.Length - keep.Length, keep, 0, keep.Length);
                    File.WriteAllText(path, string.Join("\n", keep) + (keep.Length > 0 ? "\n" : ""), new UTF8Encoding(false));
                }
                File.AppendAllText(path, sb.ToString(), new UTF8Encoding(false));
            }
            catch { /* diagnostics only */ }
        }

        private static string Trim(string s, int max)
        {
            return s.Length <= max ? s : s.Substring(0, max);
        }
    }
}
