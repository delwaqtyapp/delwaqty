using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Delwaqty.Pos.Core.Ota
{
    /// <summary>
    /// One channel entry of the OTA manifest (versions.json attached to the
    /// rolling GitHub release) - the same contract the four Flutter apps
    /// consume. <see cref="Sha256"/> is optional in older manifests, but
    /// <see cref="OtaUpdateService.DownloadLatestAsync"/> refuses to install
    /// when it is absent.
    /// </summary>
    public sealed class OtaChannelConfig
    {
        public int Version { get; set; }
        public string VersionName { get; set; } = "";
        public string Asset { get; set; } = "";
        public string Notes { get; set; } = "";
        public string Sha256 { get; set; }
    }

    public sealed class OtaManifest
    {
        public Dictionary<string, OtaChannelConfig> Channels { get; } =
            new Dictionary<string, OtaChannelConfig>(StringComparer.OrdinalIgnoreCase);

        public OtaChannelConfig ForChannel(string name)
        {
            OtaChannelConfig cfg;
            return Channels.TryGetValue(name, out cfg) ? cfg : null;
        }
    }

    public sealed class OtaCheckResult
    {
        public int Current { get; set; }
        public int Latest { get; set; }
        public bool NeedsUpdate { get; set; }
        public OtaChannelConfig Channel { get; set; }
        public string ReleaseTag { get; set; }
    }

    /// <summary>
    /// Result of <see cref="OtaUpdateService.DownloadLatestAsync"/>: either a
    /// verified installer on disk or an error code ("missing_checksum",
    /// "checksum_mismatch", or null for a plain network failure).
    /// </summary>
    public sealed class OtaDownloadResult
    {
        public string File { get; set; }
        public string Error { get; set; }
        public bool Ok { get { return File != null; } }
    }

    /// <summary>Parses versions.json; throws on structurally invalid JSON.</summary>
    public static class OtaManifestParser
    {
        public static OtaManifest Parse(string json)
        {
            using (var doc = JsonDocument.Parse(json))
            {
                var manifest = new OtaManifest();
                JsonElement channels;
                if (!doc.RootElement.TryGetProperty("channels", out channels) ||
                    channels.ValueKind != JsonValueKind.Object)
                {
                    return manifest;
                }
                foreach (var channel in channels.EnumerateObject())
                {
                    var v = channel.Value;
                    manifest.Channels[channel.Name] = new OtaChannelConfig
                    {
                        Version = GetInt(v, "version"),
                        VersionName = GetString(v, "versionName"),
                        Asset = GetString(v, "apk"),
                        Notes = GetString(v, "notes"),
                        Sha256 = v.TryGetProperty("sha256", out var h) &&
                            h.ValueKind == JsonValueKind.String ? h.GetString() : null,
                    };
                }
                return manifest;
            }
        }

        private static int GetInt(JsonElement el, string name)
        {
            JsonElement v;
            if (!el.TryGetProperty(name, out v)) return 0;
            if (v.ValueKind == JsonValueKind.Number && v.TryGetInt32(out var n)) return n;
            return 0;
        }

        private static string GetString(JsonElement el, string name)
        {
            JsonElement v;
            if (!el.TryGetProperty(name, out v) || v.ValueKind != JsonValueKind.String) return "";
            return v.GetString() ?? "";
        }
    }

    /// <summary>
    /// OTA update channel for the Windows cashier, backed by the same rolling
    /// GitHub release as the Flutter apps: the latest release tag comes from
    /// the GitHub API (never cached), the manifest and the installer asset
    /// are downloaded from that tag, and the installer is installed ONLY
    /// after its SHA-256 matches the digest published in the manifest - a
    /// poisoned CDN, release asset or man-in-the-middle must never get code
    /// onto a shop machine through this path.
    /// </summary>
    public sealed class OtaUpdateService
    {
        public const string ChannelName = "cashier";

        private const string ApiLatest =
            "https://api.github.com/repos/delwaqtyapp/delwaqty/releases/latest";
        private const string DownloadBase =
            "https://github.com/delwaqtyapp/delwaqty/releases/download/";

        private readonly HttpClient _http;

        public OtaUpdateService(HttpClient http = null)
        {
            _http = http ?? new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
        }

        /// <summary>Mutable release metadata must not reuse a cached response.</summary>
        public static Uri FreshUri(string url)
        {
            var sep = url.Contains("?") ? "&" : "?";
            return new Uri(url + sep + "ota=" + DateTime.UtcNow.Ticks);
        }

        private async Task<string> FetchLatestTagAsync()
        {
            try
            {
                using (var response = await _http.GetAsync(FreshUri(ApiLatest)).ConfigureAwait(false))
                {
                    if (!response.IsSuccessStatusCode) return null;
                    var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                    using (var doc = JsonDocument.Parse(body))
                    {
                        JsonElement tag;
                        if (doc.RootElement.TryGetProperty("tag_name", out tag) &&
                            tag.ValueKind == JsonValueKind.String)
                        {
                            var value = tag.GetString();
                            return string.IsNullOrEmpty(value) ? null : value;
                        }
                        return null;
                    }
                }
            }
            catch
            {
                return null;
            }
        }

        /// <summary>Fetches and parses the manifest pinned to a release tag.</summary>
        public async Task<OtaManifest> FetchManifestForTagAsync(string tag)
        {
            try
            {
                var uri = FreshUri(DownloadBase + tag + "/versions.json");
                using (var response = await _http.GetAsync(uri).ConfigureAwait(false))
                {
                    if (!response.IsSuccessStatusCode) return null;
                    var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                    return OtaManifestParser.Parse(body);
                }
            }
            catch
            {
                return null;
            }
        }

        /// <summary>
        /// Compares the installed OTA build number against the cashier
        /// channel of the latest release manifest. Never throws: any
        /// reachability or parse problem means "no update".
        /// </summary>
        public async Task<OtaCheckResult> CheckForUpdateAsync(int currentBuild)
        {
            var tag = await FetchLatestTagAsync().ConfigureAwait(false);
            var manifest = tag == null ? null : await FetchManifestForTagAsync(tag).ConfigureAwait(false);
            if (manifest == null)
            {
                return new OtaCheckResult { Current = currentBuild, Latest = currentBuild };
            }
            var channel = manifest.ForChannel(ChannelName);
            var latest = channel == null ? currentBuild : channel.Version;
            return new OtaCheckResult
            {
                Current = currentBuild,
                Latest = latest,
                NeedsUpdate = latest > currentBuild,
                Channel = channel,
                ReleaseTag = tag,
            };
        }

        /// <summary>
        /// Downloads the installer for an offered update into
        /// <paramref name="targetDir"/> and verifies its SHA-256. Writes to a
        /// .part file first so an interrupted download is never mistaken for
        /// a finished one; an already-downloaded, verified file is reused.
        /// Does NOT start the installer - the caller owns the install step.
        /// </summary>
        public async Task<OtaDownloadResult> DownloadLatestAsync(
            OtaCheckResult offered, string targetDir, IProgress<double> progress = null)
        {
            try
            {
                var tag = offered == null ? null : offered.ReleaseTag;
                var channel = offered == null ? null : offered.Channel;
                if (string.IsNullOrEmpty(tag) || channel == null || string.IsNullOrEmpty(channel.Asset))
                {
                    return new OtaDownloadResult();
                }

                var expectedHash = (channel.Sha256 ?? "").Trim().ToLowerInvariant();
                if (expectedHash.Length == 0)
                {
                    // A release without a published digest cannot be trusted.
                    return new OtaDownloadResult { Error = "missing_checksum" };
                }

                Directory.CreateDirectory(targetDir);
                var target = Path.Combine(targetDir, channel.Asset);
                if (!File.Exists(target) || new FileInfo(target).Length == 0)
                {
                    var uri = new Uri(DownloadBase + tag + "/" + channel.Asset);
                    var partial = target + ".part";
                    using (var response = await _http
                        .GetAsync(uri, HttpCompletionOption.ResponseHeadersRead)
                        .ConfigureAwait(false))
                    {
                        if (!response.IsSuccessStatusCode) return new OtaDownloadResult();
                        var total = response.Content.Headers.ContentLength;
                        using (var input = await response.Content.ReadAsStreamAsync().ConfigureAwait(false))
                        using (var output = new FileStream(partial, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            var buffer = new byte[81920];
                            long received = 0;
                            int read;
                            while ((read = await input.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false)) > 0)
                            {
                                await output.WriteAsync(buffer, 0, read).ConfigureAwait(false);
                                received += read;
                                if (progress != null && total.HasValue && total.Value > 0)
                                {
                                    progress.Report(Math.Min(1.0, (double)received / total.Value));
                                }
                            }
                        }
                    }
                    File.Move(partial, target);
                }

                if (!await VerifySha256Async(target, expectedHash).ConfigureAwait(false))
                {
                    // Tampered or truncated artifact: delete it and refuse.
                    try { File.Delete(target); } catch { }
                    return new OtaDownloadResult { Error = "checksum_mismatch" };
                }

                if (progress != null) progress.Report(1.0);
                return new OtaDownloadResult { File = target };
            }
            catch
            {
                return new OtaDownloadResult();
            }
        }

        /// <summary>Streams a file through SHA-256 and compares with the expected hex digest.</summary>
        public static async Task<bool> VerifySha256Async(string path, string expected)
        {
            if (string.IsNullOrEmpty(expected) || expected.Length != 64) return false;
            using (var sha = SHA256.Create())
            using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                var hash = await Task.Run(() => sha.ComputeHash(stream)).ConfigureAwait(false);
                var hex = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
                return hex == expected.ToLowerInvariant();
            }
        }
    }
}
