using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
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

        private const string Net8Asset = "delwaqty-cashier-setup-net8-b12.exe";
        private const string Net48Asset = "delwaqty-cashier-setup-net48-b15.exe";

        private const string ManifestJson = @"{
  ""sourceCommit"": ""abc123"",
  ""channels"": {
    ""customer"": { ""version"": 8, ""versionName"": ""1.0.0"", ""apk"": ""delwaqty-customer-8.apk"", ""notes"": ""x"" },
    ""cashier-net8"": {
      ""version"": 12,
      ""versionName"": ""1.0.0-b12"",
      ""apk"": """ + Net8Asset + @""",
      ""notes"": ""تحديث الكاشير"",
      ""sha256"": ""{SHA}""
    },
    ""cashier-net48"": {
      ""version"": 15,
      ""versionName"": ""1.0.0-b15"",
      ""apk"": """ + Net48Asset + @""",
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

        private static string ReleaseJson(string tag)
        {
            return @"{""tag_name"":""" + tag + @"""}";
        }

        [Fact]
        public void Manifest_parses_runtime_channels_and_preserves_others()
        {
            var manifest = OtaManifestParser.Parse(ManifestJson.Replace("{SHA}", new string('a', 64)));
            Assert.NotNull(manifest.ForChannel("customer")); // unknown-to-POS channels survive parsing
            Assert.Equal(12, manifest.ForChannel("cashier-net8").Version);
            Assert.Equal(Net8Asset, manifest.ForChannel("cashier-net8").Asset);
            Assert.Equal(15, manifest.ForChannel("cashier-net48").Version);
        }

        [Theory]
        [InlineData(4, "cashier-net48")]
        [InlineData(8, "cashier-net8")]
        public void Runtime_maps_to_its_own_channel(int clrMajor, string expected)
        {
            Assert.Equal(expected, OtaUpdateService.ChannelForRuntime(new Version(clrMajor, 0)));
        }

        [Fact]
        public async Task Net48_build_selects_the_net48_installer_not_net8()
        {
            var payload = Encoding.UTF8.GetBytes("net48 installer bytes");
            var manifest = ManifestJson.Replace("{SHA}", Sha256Hex(payload));
            var bytes = new StubBytesHandler()
                .OkText(ReleaseJson("development"))
                .OkText(manifest)
                .OkBytes(payload);
            var service = new OtaUpdateService(new HttpClient(bytes));

            var check = await service.CheckForUpdateAsync(10, "cashier-net48");
            Assert.Null(check.Error);
            Assert.True(check.NeedsUpdate);
            Assert.Equal(15, check.Latest);
            Assert.Equal(Net48Asset, check.Channel.Asset);

            var done = await service.DownloadLatestAsync(check, _dir);
            Assert.True(done.Ok);
            Assert.Equal(Net48Asset, Path.GetFileName(done.Installer.File));
            Assert.Equal(3, bytes.Requests.Count); // release, manifest, installer - never the net8 asset
            Assert.DoesNotContain(bytes.Requests, r => r.Url.Contains("net8"));
        }

        [Fact]
        public async Task Legacy_single_cashier_channel_is_not_a_compatible_offer()
        {
            var legacy = @"{""channels"":{""cashier"":{""version"":99,""apk"":""x.exe"",""sha256"":""" + new string('a', 64) + @"""}}}";
            var handler = new StubHandler().Ok(ReleaseJson("development")).Ok(legacy);
            var service = new OtaUpdateService(new HttpClient(handler));
            var check = await service.CheckForUpdateAsync(1, "cashier-net8");
            Assert.Equal("no_compatible_channel", check.Error);
            Assert.False(check.NeedsUpdate);
        }

        [Fact]
        public async Task Unreachable_release_is_unavailable_not_up_to_date()
        {
            var handler = new StubHandler(); // no scripted response => 404
            var service = new OtaUpdateService(new HttpClient(handler));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            Assert.False(check.NeedsUpdate);
            Assert.NotNull(check.Error);
        }

        [Fact]
        public async Task Missing_checksum_refuses_download()
        {
            var manifest = ManifestJson.Replace(@"""sha256"": ""{SHA}""", @"""sha256"": null");
            var handler = new StubHandler().Ok(ReleaseJson("development")).Ok(manifest);
            var service = new OtaUpdateService(new HttpClient(handler));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            var result = await service.DownloadLatestAsync(check, _dir);
            Assert.Equal("missing_checksum", result.Error);
            Assert.False(Directory.EnumerateFiles(_dir).Any());
        }

        [Theory]
        [InlineData("../evil.exe")]
        [InlineData("..\\evil.exe")]
        [InlineData("sub/dir.exe")]
        [InlineData("C:/windows/evil.exe")]
        [InlineData("setup.msi")]
        [InlineData("")]
        public async Task Poisoned_asset_name_is_refused_before_any_download(string asset)
        {
            var manifest = ManifestJson
                .Replace(Net8Asset, asset.Replace("\\", "\\\\").Replace("\"", ""))
                .Replace("{SHA}", new string('a', 64));
            var handler = new StubHandler().Ok(ReleaseJson("development")).Ok(manifest);
            var service = new OtaUpdateService(new HttpClient(handler));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            if (check.Error != null) return; // empty asset already fails the offer
            var result = await service.DownloadLatestAsync(check, _dir);
            Assert.Equal("invalid_asset", result.Error);
            Assert.Equal(2, handler.Requests.Count); // release + manifest only, no installer fetch
        }

        [Theory]
        [InlineData("delwaqty-cashier-setup-net8-b12.exe", true)]
        [InlineData("delwaqty cashier setup b12.exe", true)] // spaces are fine in a plain name
        [InlineData("SETUP.EXE", true)]
        [InlineData("setup.exe.part", false)]
        [InlineData("..exe", false)]
        public void Asset_name_validation(string name, bool expected)
        {
            Assert.Equal(expected, OtaUpdateService.IsSafeAssetName(name));
        }

        [Fact]
        public async Task Asset_and_tag_are_url_encoded_in_requests()
        {
            var payload = Encoding.UTF8.GetBytes("installer");
            var asset = "delwaqty cashier setup b12.exe";
            var manifest = ManifestJson.Replace(Net8Asset, asset).Replace("{SHA}", Sha256Hex(payload));
            var bytes = new StubBytesHandler().OkText(ReleaseJson("development")).OkText(manifest).OkBytes(payload);
            var service = new OtaUpdateService(new HttpClient(bytes));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            var result = await service.DownloadLatestAsync(check, _dir);
            Assert.True(result.Ok);
            Assert.Contains("%20", bytes.Requests[2].Url);
        }

        [Fact]
        public async Task Tampered_download_is_deleted_and_refused()
        {
            var payload = Encoding.UTF8.GetBytes("evil bytes");
            var manifest = ManifestJson.Replace("{SHA}", Sha256Hex(Encoding.UTF8.GetBytes("good bytes")));
            var bytes = new StubBytesHandler().OkText(ReleaseJson("development")).OkText(manifest).OkBytes(payload);
            var service = new OtaUpdateService(new HttpClient(bytes));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            var result = await service.DownloadLatestAsync(check, _dir);
            Assert.Equal("checksum_mismatch", result.Error);
            Assert.False(Directory.EnumerateFiles(_dir).Any()); // neither the file nor a .part survives
        }

        [Fact]
        public async Task Short_digest_is_rejected()
        {
            var payload = Encoding.UTF8.GetBytes("installer");
            var manifest = ManifestJson.Replace("{SHA}", "abcd");
            var bytes = new StubBytesHandler().OkText(ReleaseJson("development")).OkText(manifest).OkBytes(payload);
            var service = new OtaUpdateService(new HttpClient(bytes));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            var result = await service.DownloadLatestAsync(check, _dir);
            Assert.Equal("checksum_mismatch", result.Error);
        }

        [Fact]
        public async Task Verified_download_holds_bytes_and_reverify_catches_a_swap()
        {
            var payload = Encoding.UTF8.GetBytes("the real installer");
            var manifest = ManifestJson.Replace("{SHA}", Sha256Hex(payload));
            var bytes = new StubBytesHandler().OkText(ReleaseJson("development")).OkText(manifest).OkBytes(payload);
            var service = new OtaUpdateService(new HttpClient(bytes));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            var result = await service.DownloadLatestAsync(check, _dir);
            Assert.True(result.Ok);
            Assert.True(result.Installer.Reverify());

            // An attacker swapping the file after the download is caught at launch time.
            File.WriteAllBytes(result.Installer.File, Encoding.UTF8.GetBytes("swapped installer"));
            Assert.False(result.Installer.Reverify());
        }

        [Fact]
        public async Task Version_keyed_cache_is_reused_only_after_digest_recheck()
        {
            var payload = Encoding.UTF8.GetBytes("the real installer");
            var manifest = ManifestJson.Replace("{SHA}", Sha256Hex(payload));
            var bytes = new StubBytesHandler().OkText(ReleaseJson("development")).OkText(manifest).OkBytes(payload);
            var service = new OtaUpdateService(new HttpClient(bytes));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            var first = await service.DownloadLatestAsync(check, _dir);
            Assert.True(first.Ok);
            Assert.Equal(3, bytes.Requests.Count);

            var second = await service.DownloadLatestAsync(check, _dir);
            Assert.True(second.Ok);
            Assert.Equal(3, bytes.Requests.Count); // cache hit, no second download
        }

        [Fact]
        public async Task Oversized_installer_is_refused()
        {
            var payload = Encoding.UTF8.GetBytes("01234567890123456789");
            var manifest = ManifestJson.Replace("{SHA}", Sha256Hex(payload));
            var bytes = new StubBytesHandler().OkText(ReleaseJson("development")).OkText(manifest).OkBytes(payload);
            var service = new OtaUpdateService(new HttpClient(bytes), maxInstallerBytes: 10);
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            var result = await service.DownloadLatestAsync(check, _dir);
            Assert.Equal("too_large", result.Error);
            Assert.False(Directory.EnumerateFiles(_dir).Any());
        }

        [Fact]
        public async Task Cancellation_cleans_up_the_partial_file()
        {
            var payload = Encoding.UTF8.GetBytes("the real installer");
            var manifest = ManifestJson.Replace("{SHA}", Sha256Hex(payload));
            var bytes = new StubBytesHandler().OkText(ReleaseJson("development")).OkText(manifest).OkBytes(payload);
            var service = new OtaUpdateService(new HttpClient(bytes));
            var check = await service.CheckForUpdateAsync(10, "cashier-net8");
            using (var cts = new CancellationTokenSource())
            {
                cts.Cancel();
                var result = await service.DownloadLatestAsync(check, _dir, cancellationToken: cts.Token);
                Assert.Equal("cancelled", result.Error);
            }
            Assert.False(Directory.EnumerateFiles(_dir).Any());
        }

        [Fact]
        public async Task Same_version_is_not_an_update()
        {
            var manifest = ManifestJson.Replace("{SHA}", new string('a', 64));
            var handler = new StubHandler().Ok(ReleaseJson("development")).Ok(manifest);
            var service = new OtaUpdateService(new HttpClient(handler));
            var check = await service.CheckForUpdateAsync(12, "cashier-net8");
            Assert.Null(check.Error);
            Assert.False(check.NeedsUpdate);
        }
    }

    /// <summary>Stub handler that can serve raw bytes (installer payloads).</summary>
    internal sealed class StubBytesHandler : HttpMessageHandler
    {
        public readonly System.Collections.Generic.List<(HttpMethod Method, string Url)> Requests =
            new System.Collections.Generic.List<(HttpMethod, string)>();
        private readonly System.Collections.Generic.Queue<HttpContent> _responses =
            new System.Collections.Generic.Queue<HttpContent>();

        public StubBytesHandler OkText(string body)
        {
            _responses.Enqueue(new StringContent(body));
            return this;
        }

        public StubBytesHandler OkBytes(byte[] body)
        {
            _responses.Enqueue(new ByteArrayContent(body));
            return this;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add((request.Method, request.RequestUri.AbsoluteUri));
            if (_responses.Count == 0)
            {
                return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound)
                {
                    Content = new StringContent("{}"),
                });
            }
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = _responses.Dequeue(),
            });
        }
    }
}
