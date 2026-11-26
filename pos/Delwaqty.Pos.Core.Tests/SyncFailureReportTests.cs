using System;
using System.Collections.Generic;
using System.IO;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class SyncFailureReportTests
    {
        private static List<SyncEngine.OpFailure> Make(int n)
        {
            var l = new List<SyncEngine.OpFailure>();
            for (var i = 0; i < n; i++)
                l.Add(new SyncEngine.OpFailure { OpId = "op-" + i, Type = "sale", Reason = "R" + i });
            return l;
        }

        [Fact]
        public void Summarize_Empty_Is_Empty()
        {
            Assert.Equal("", SyncFailureReport.Summarize(new List<SyncEngine.OpFailure>(), 3));
            Assert.Equal("", SyncFailureReport.Summarize(null, 3));
        }

        [Fact]
        public void Summarize_Shows_First_N_And_Remaining_Count()
        {
            var text = SyncFailureReport.Summarize(Make(5), 3);
            Assert.Equal("sale: R0\nsale: R1\nsale: R2\n+2", text);
        }

        [Fact]
        public void Summarize_Handles_Missing_Fields_And_Long_Reason()
        {
            var f = new List<SyncEngine.OpFailure>
            {
                new SyncEngine.OpFailure { OpId = "a", Type = null, Reason = null },
                new SyncEngine.OpFailure { OpId = "b", Type = "sale", Reason = new string('x', 500) },
            };
            var lines = SyncFailureReport.Summarize(f, 3).Split('\n');
            Assert.Equal("op: UNKNOWN", lines[0]);
            Assert.Equal("sale: " + new string('x', 80), lines[1]);
        }

        [Fact]
        public void Append_Writes_Once_Per_Op_And_Reason_And_Never_Throws()
        {
            var dir = Path.Combine(Path.GetTempPath(), "sfr-" + Guid.NewGuid());
            Directory.CreateDirectory(dir);
            try
            {
                var seen = new HashSet<string>();
                SyncFailureReport.Append(dir, Make(2), DateTimeOffset.UtcNow, seen);
                SyncFailureReport.Append(dir, Make(2), DateTimeOffset.UtcNow, seen); // same ops again: no new lines
                var changed = Make(1); changed[0].Reason = "OTHER";
                SyncFailureReport.Append(dir, changed, DateTimeOffset.UtcNow, seen); // same op, new reason: logged
                var lines = File.ReadAllLines(Path.Combine(dir, SyncFailureReport.LogFileName));
                Assert.Equal(3, lines.Length);
                Assert.Contains("op-1 sale R1", lines[1]);
                SyncFailureReport.Append(Path.Combine(dir, "no", "such", "dir"), Make(1), DateTimeOffset.UtcNow, new HashSet<string>());
            }
            finally { Directory.Delete(dir, true); }
        }

        [Fact]
        public void Append_Cuts_An_Oversized_Log_To_Its_Newest_Half_Not_Deleted()
        {
            var dir = Path.Combine(Path.GetTempPath(), "sfr-" + Guid.NewGuid());
            Directory.CreateDirectory(dir);
            try
            {
                var path = Path.Combine(dir, SyncFailureReport.LogFileName);
                var big = new System.Text.StringBuilder();
                var n = 0;
                while (big.Length <= SyncFailureReport.MaxBytes) big.Append("line-" + (n++) + " " + new string('x', 90) + "\n");
                File.WriteAllText(path, big.ToString());
                SyncFailureReport.Append(dir, Make(1), DateTimeOffset.UtcNow, new HashSet<string>());
                var lines = File.ReadAllLines(path);
                Assert.True(lines.Length > 10 && lines.Length < n);
                Assert.Contains("line-" + (n - 1) + " ", lines[lines.Length - 2]); // newest old line kept
                Assert.Contains("op-0 sale R0", lines[lines.Length - 1]);
                Assert.DoesNotContain("line-0 ", string.Join("\n", lines));
            }
            finally { Directory.Delete(dir, true); }
        }
    }
}
