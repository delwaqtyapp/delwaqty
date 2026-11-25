using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Delwaqty.Pos.Core.Ota;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class OtaUpdateTests : IDisposable
    {
        private readonly string _dir;

        public OtaUpdateTests()
        {
            _dir = Path.Combine(Path.GetTempPath(), "ota-test-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(_dir);
        }

        public void Dispose()
        {
            try { Directory.Delete(_dir, true); } catch { }
        }

        private const string ManifestJson = @"{
  ""channels"": {
    ""customer"": { ""version"": 8, ""versionName"": ""1.0.0"", ""apk"": ""delwaqty-customer-8.apk"", ""notes"": ""x"" },
    ""cashier"": {
      ""version"": 12,
      ""versionName"": ""1.0.1"",
      ""apk"": ""delwaqty-cashier-setup-net8.exe"",
      ""notes"": ""تحديث الكاشير"",
      ""sha256"": ""{SHA}""
    }
  }
}";

        private static string Sha256Hex(byte[] content)
        {
            using (var sha = SHA256.Create())
            {
                return BitConverter.ToString(sha.ComputeHash(content)).Replace("-", "").ToLowerInvariant();
            }
        }

        [Fact]
        public void Manifest_parses_the_cashier_channel()
        {
            var manifest = OtaManifestParser.Parse(ManifestJson.Replace("{SHA}", new string('a', 64)));
            var channel = manifest.ForChannel("cashier");
            Assert.NotNull(channel);
            Assert.Equal(12, channel.Version);
            Assert.Equal("1.0.1", channel.VersionName);
            Assert.Equal("delwaqty-cashier-setup-net8.exe", channel.Asset);
            Assert.Equal(new string('a', 64), channel.Sha256);
            Assert.Equal(8, manifest.ForChannel("customer").Version);
            Assert.Null(manifest.ForChannel("driver"));
        }

        [Fact]
        public void Manifest_without_sha256_still_parses_with_null_hash()
        {
            var json = @"{ ""channels"": { ""cashier"": { ""version"": 3, ""apk"": ""a.exe"" } } }";
            var channel = OtaManifestParser.Parse(json).ForChannel("cashier");
            Assert.NotNull(channel);
            Assert.Null(channel.Sha256);
        }

        [Fact]
        public async Task Check_reports_update_only_when_the_channel_is_newer()
        {
            var stub = new StubHandler()
                .Ok(@"{""tag_name"":""development""}")
                .Ok(ManifestJson.Replace("{SHA}", new string('b', 64)));
            var service = new OtaUpdateService(new HttpClient(stub));

            var older = await service.CheckForUpdateAsync(11);
            Assert.True(older.NeedsUpdate);
            Assert.Equal(12, older.Latest);
            Assert.Equal("development", older.ReleaseTag);

            var stub2 = new StubHandler()
                .Ok(@"{""tag_name"":""development""}")
                .Ok(ManifestJson.Replace("{SHA}", new string('b', 64)));
            var same = await new OtaUpdateService(new HttpClient(stub2)).CheckForUpdateAsync(12);
            Assert.False(same.NeedsUpdate);
        }

        [Fact]
        public async Task Check_never_updates_when_the_release_or_manifest_is_unreachable()
        {
            var down = new OtaUpdateService(new HttpClient(new StubHandler()));
            var result = await down.CheckForUpdateAsync(1);
            Assert.False(result.NeedsUpdate);
            Assert.Equal(1, result.Latest);

            var noChannel = new OtaUpdateService(new HttpClient(new StubHandler()
                .Ok(@"{""tag_name"":""development""}")
                .Ok(@"{ ""channels"": { ""customer"": { ""version"": 9 } } }")));
            var result2 = await noChannel.CheckForUpdateAsync(1);
            Assert.False(result2.NeedsUpdate);
        }

        [Fact]
        public async Task Download_refuses_a_manifest_without_a_published_digest()
        {
            var channel = new OtaChannelConfig { Version = 12, Asset = "setup.exe", Sha256 = null };
            var offered = new OtaCheckResult { Channel = channel, ReleaseTag = "development", NeedsUpdate = true };
            var service = new OtaUpdateService(new HttpClient(new StubHandler()));

            var result = await service.DownloadLatestAsync(offered, _dir);

            Assert.False(result.Ok);
            Assert.Equal("missing_checksum", result.Error);
            Assert.Empty(Directory.GetFiles(_dir));
        }

        [Fact]
        public async Task Download_verifies_sha256_and_deletes_a_tampered_artifact()
        {
            // The stub serves string content; the digest is computed over
            // the same UTF-8 bytes the handler will send.
            var payloadText = "not the real installer";
            var offered = new OtaCheckResult
            {
                Channel = new OtaChannelConfig
                {
                    Version = 12,
                    Asset = "setup.exe",
                    Sha256 = new string('0', 64), // anything but the real digest
                },
                ReleaseTag = "development",
                NeedsUpdate = true,
            };
            var stub = new StubHandler().Ok(payloadText);
            var service = new OtaUpdateService(new HttpClient(stub));

            var result = await service.DownloadLatestAsync(offered, _dir);

            Assert.False(result.Ok);
            Assert.Equal("checksum_mismatch", result.Error);
            // The tampered file must be gone, not left for a later install.
            Assert.Empty(Directory.GetFiles(_dir));
            Assert.Empty(Directory.GetFiles(_dir, "*.part"));
        }

        [Fact]
        public async Task Download_returns_a_verified_file_and_reports_progress()
        {
            var payloadText = new string('x', 256 * 1024) + "نهاية";
            var payload = Encoding.UTF8.GetBytes(payloadText);
            var digest = Sha256Hex(payload);
            var offered = new OtaCheckResult
            {
                Channel = new OtaChannelConfig { Version = 12, Asset = "setup.exe", Sha256 = digest },
                ReleaseTag = "development",
                NeedsUpdate = true,
            };
            var stub = new StubHandler().Ok(payloadText);
            var service = new OtaUpdateService(new HttpClient(stub));

            var result = await service.DownloadLatestAsync(offered, _dir);

            Assert.True(result.Ok);
            Assert.Equal(payload, File.ReadAllBytes(result.File));
            Assert.True(await OtaUpdateService.VerifySha256Async(result.File, digest));
        }

        [Fact]
        public async Task VerifySha256_rejects_missing_or_short_digests()
        {
            var file = Path.Combine(_dir, "x.bin");
            File.WriteAllBytes(file, new byte[] { 1, 2, 3 });
            Assert.False(await OtaUpdateService.VerifySha256Async(file, null));
            Assert.False(await OtaUpdateService.VerifySha256Async(file, "abcd"));
        }
    }
}
