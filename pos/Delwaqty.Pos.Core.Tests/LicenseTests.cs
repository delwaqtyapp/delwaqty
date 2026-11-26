using System;
using System.Text;
using Delwaqty.Pos.Core.Licensing;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class LicenseTests
    {
        private static string MakeKey(string payload, string sig)
        {
            var b64 = LicenseKey.Base64UrlEncode(Encoding.UTF8.GetBytes(payload));
            return "DLWQ1." + b64 + "." + sig;
        }

        private static readonly string Sig64 =
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

        [Fact]
        public void Parses_Trial_Key()
        {
            var id = Guid.NewGuid().ToString();
            var merchant = Guid.NewGuid().ToString();
            var payload = id + "|" + merchant + "|trial|2026-12-22 03:25:12.345678+02";
            Assert.True(LicenseKey.TryParse(MakeKey(payload, Sig64), out var info, out var err), err);
            Assert.Equal(id, info.Id);
            Assert.Equal(merchant, info.MerchantId);
            Assert.Equal("trial", info.Plan);
            Assert.NotNull(info.ExpiresAt);
            Assert.Equal(2, info.ExpiresAt.Value.Offset.Hours);
        }

        [Theory]
        [InlineData("123456789012")]
        [InlineData("1234-5678-9012")]
        [InlineData("  1234 5678 9012  ")]
        [InlineData("1234\u20105678\u20139012")]
        [InlineData("\u0661\u0662\u0663\u0664-\u0665\u0666\u0667\u0668-\u0669\u0660\u0661\u0662")]
        [InlineData("\u06F1\u06F2\u06F3\u06F4\u06F5\u06F6\u06F7\u06F8\u06F9\u06F0\u06F1\u06F2")]
        public void Short_Key_Normalizes_To_Twelve_Ascii_Digits(string typed)
        {
            Assert.True(LicenseKey.TryNormalize(typed, out var canonical, out var err), err);
            Assert.Equal("123456789012", canonical);
        }

        [Theory]
        [InlineData("")]
        [InlineData("   ")]
        public void Empty_Key_Is_Rejected(string typed)
        {
            Assert.False(LicenseKey.TryNormalize(typed, out var canonical, out var err));
            Assert.Equal("EMPTY_KEY", err);
            Assert.Null(canonical);
        }

        [Theory]
        [InlineData("12345678901")]
        [InlineData("1234567890123")]
        [InlineData("1234-5678")]
        public void Wrong_Length_Digits_Are_Rejected(string typed)
        {
            Assert.False(LicenseKey.TryNormalize(typed, out var canonical, out var err));
            Assert.Equal("BAD_SHORT_KEY_LENGTH", err);
        }

        [Fact]
        public void Legacy_Key_Still_Accepted_And_Left_Unchanged()
        {
            var payload = Guid.NewGuid() + "|" + Guid.NewGuid() + "|trial|2026-12-22 03:25:12.345678+02";
            var key = MakeKey(payload, Sig64);
            Assert.True(LicenseKey.TryNormalize("  " + key + " ", out var canonical, out var err), err);
            Assert.Equal(key, canonical);
        }

        [Fact]
        public void Garbage_With_Twelve_Digits_Inside_Is_Not_A_Short_Key()
        {
            Assert.False(LicenseKey.TryNormalize("abc123456789012xyz", out var canonical, out var err));
            Assert.Equal("BAD_FORMAT", err);
        }

        [Fact]
        public void FormatShort_Groups_By_Four()
        {
            Assert.Equal("1234-5678-9012", LicenseKey.FormatShort("123456789012"));
        }

        [Fact]
        public void Parses_Lifetime_Key()
        {
            var payload = Guid.NewGuid() + "|" + Guid.NewGuid() + "|core_lifetime|lifetime";
            Assert.True(LicenseKey.TryParse(MakeKey(payload, Sig64), out var info, out var err), err);
            Assert.Null(info.ExpiresAt);
        }

        [Theory]
        [InlineData("")]
        [InlineData("DLWQ1")]
        [InlineData("DLWQ2.abc.def")]
        [InlineData("DLWQ1.!!!.0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")]
        [InlineData("DLWQ1.abc.short")]
        public void Rejects_Bad_Keys(string key)
        {
            Assert.False(LicenseKey.TryParse(key, out _, out _));
        }

        [Fact]
        public void Seal_Roundtrips_And_Detects_Tamper()
        {
            var key = LocalLicenseSeal.NewDeviceKey();
            var payload = "id|merchant|trial|lifetime|device-1|2026-11-22T00:00:00.0000000Z";
            var seal = LocalLicenseSeal.Seal(payload, key);
            Assert.True(LocalLicenseSeal.Verify(payload, seal, key));
            Assert.False(LocalLicenseSeal.Verify(payload + "x", seal, key));
            Assert.False(LocalLicenseSeal.Verify(payload, seal, LocalLicenseSeal.NewDeviceKey()));
        }

        [Fact]
        public void Evaluates_Status()
        {
            var now = DateTimeOffset.UtcNow;
            var active = new LicenseInfo { Plan = "core_annual", ExpiresAt = now.AddDays(10) };
            Assert.Equal(LicenseStatus.Active, LicenseEvaluator.Evaluate(active, now, 7));
            var trial = new LicenseInfo { Plan = "trial", ExpiresAt = now.AddDays(10) };
            Assert.Equal(LicenseStatus.Trial, LicenseEvaluator.Evaluate(trial, now, 7));
            var grace = new LicenseInfo { Plan = "core_annual", ExpiresAt = now.AddDays(-2) };
            Assert.Equal(LicenseStatus.ExpiredInGrace, LicenseEvaluator.Evaluate(grace, now, 7));
            var expired = new LicenseInfo { Plan = "core_annual", ExpiresAt = now.AddDays(-30) };
            Assert.Equal(LicenseStatus.Expired, LicenseEvaluator.Evaluate(expired, now, 7));
            var lifetime = new LicenseInfo { Plan = "core_lifetime", ExpiresAt = null };
            Assert.Equal(LicenseStatus.Active, LicenseEvaluator.Evaluate(lifetime, now, 7));
        }
    }
}
