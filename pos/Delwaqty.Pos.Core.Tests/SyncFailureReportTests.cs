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
        public void Append_Writes_One_Line_Per_Failure_And_Never_Throws()
        {
            var dir = Path.Combine(Path.GetTempPath(), "sfr-" + Guid.NewGuid());
            Directory.CreateDirectory(dir);
            try
            {
                SyncFailureReport.Append(dir, Make(2), DateTimeOffset.UtcNow);
                SyncFailureReport.Append(dir, Make(1), DateTimeOffset.UtcNow);
                var lines = File.ReadAllLines(Path.Combine(dir, SyncFailureReport.LogFileName));
                Assert.Equal(3, lines.Length);
                Assert.Contains("op-1 sale R1", lines[1]);
                // Bad directory: must not throw.
                SyncFailureReport.Append(Path.Combine(dir, "no", "such", "dir"), Make(1), DateTimeOffset.UtcNow);
            }
            finally { Directory.Delete(dir, true); }
        }
    }
}
