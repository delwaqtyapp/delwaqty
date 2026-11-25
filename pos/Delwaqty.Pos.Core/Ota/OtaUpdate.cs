using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
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
        /// <summary>
        /// Null when the check reached the manifest. Any non-null value
        /// ("network", "parse", "no_compatible_channel") means UNAVAILABLE,
        /// which the UI must show distinctly from "up to date".
        /// </summary>
        public string Error { get; set; }
    }

    /// <summary>
    /// Result of <see cref="OtaUpdateService.DownloadLatestAsync"/>: either a
    /// verified installer or an error code ("missing_checksum",
    /// "checksum_mismatch", "invalid_asset", "too_large", "cancelled",
    /// or null for a plain network failure).
    /// </summary>
    public sealed class OtaDownloadResult
    {
        public OtaVerifiedInstaller Installer { get; set; }
        public string Error { get; set; }
        public bool Ok { get { return Installer != null; } }
    }

    /// <summary>
    /// An installer whose bytes were SHA-256 verified against the manifest
    /// digest. The verified bytes are HELD in memory; <see cref="Reverify"/>
    /// re-hashes the file on disk right before it is launched, so a file
    /// swapped after the download can never be executed.
    /// </summary>
    public sealed class OtaVerifiedInstaller
    {
        public string File { get; private set; }
        public string ExpectedSha256 { get; private set; }
        private readonly byte[] _verifiedBytes;

        public OtaVerifiedInstaller(string file, string expectedSha256, byte[] verifiedBytes)
        {
            File = file;
            ExpectedSha256 = expectedSha256;
            _verifiedBytes = verifiedBytes;
        }

        /// <summary>
        /// Reads the file back and proves it is byte-identical to the bytes
        /// that passed the manifest-digest check. Must be called immediately
        /// before launching the installer.
        /// </summary>
        public bool Reverify()
        {
            try
            {
                if (string.IsNullOrEmpty(File) || !System.IO.File.Exists(File)) return false;
                var onDisk = System.IO.File.ReadAllBytes(File);
                if (onDisk.Length != _verifiedBytes.Length) return false;
                return onDisk.SequenceEqual(_verifiedBytes) && Sha256Hex(onDisk) == ExpectedSha256;
            }
            catch
            {
                return false;
            }
        }

        internal static string Sha256Hex(byte[] content)
        {
            using (var sha = SHA256.Create())
            {
                return BitConverter.ToString(sha.ComputeHash(content)).Replace("-", "").ToLowerInvariant();
            }
        }
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
    /// after its SHA-256 matches the digest published in the manifest. The
    /// Inno installer is NOT digitally signed - the manifest digest, fetched
    /// over the GitHub API, is the integrity anchor, and a poisoned CDN or
    /// release asset must never get code onto a shop machine through this
    /// path.
    /// </summary>
    public sealed class OtaUpdateService
    {
        /// <summary>Legacy single cashier channel; superseded by the per-runtime channels.</summary>
        public const string LegacyChannelName = "cashier";
        public const string ChannelNet8 = "cashier-net8";
        public const string ChannelNet48 = "cashier-net48";

        private const string ApiLatest =
            "https://api.github.com/repos/delwaqtyapp/delwaqty/releases/latest";
        private const string DownloadBase =
            "https://github.com/delwaqtyapp/delwaqty/releases/download/";
        private const string UserAgent = "delwaqty-cashier-ota/1.0";

        /// <summary>Installers are Inno setups of a self-contained app; anything bigger is an attack or a bug.</summary>
        public const long DefaultMaxInstallerBytes = 500L * 1024 * 1024;
        private static readonly TimeSpan BodyDeadline = TimeSpan.FromMinutes(5);

        private readonly HttpClient _http;
        private readonly long _maxInstallerBytes;

        public OtaUpdateService(HttpClient http = null, long maxInstallerBytes = DefaultMaxInstallerBytes)
        {
            _http = http ?? new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
            _maxInstallerBytes = maxInstallerBytes;
            try
            {
                // GitHub's API requires a User-Agent; set one even on an
                // injected client unless the caller already chose one.
                if (_http.DefaultRequestHeaders.UserAgent.Count == 0)
                {
                    _http.DefaultRequestHeaders.UserAgent.ParseAdd(UserAgent);
                }
            }
            catch { /* a locked header collection must never break updates */ }
        }

        /// <summary>
        /// The manifest channel this running build consumes. The WPF app
        /// ships both net48 and net8.0-windows builds and they are different
        /// binaries, so each runtime has its own channel; a build NEVER picks
        /// up the other runtime's installer. The CLR major version is 4.x on
        /// .NET Framework and 5+ on modern .NET.
        /// </summary>
        public static string RuntimeChannel()
        {
            return ChannelForRuntime(Environment.Version);
        }

        public static string ChannelForRuntime(Version clrVersion)
        {
            return clrVersion != null && clrVersion.Major >= 5 ? ChannelNet8 : ChannelNet48;
        }

        /// <summary>Mutable release metadata must not reuse a cached response.</summary>
        public static Uri FreshUri(string url)
        {
            var sep = url.Contains("?") ? "&" : "?";
            return new Uri(url + sep + "ota=" + DateTime.UtcNow.Ticks);
        }

        /// <summary>
        /// The manifest's asset field must be a plain .exe FILE NAME: no
        /// directories, no rooted paths, no parent traversal. Anything else
        /// is a poisoned manifest and is refused before any URL is built.
        /// </summary>
        public static bool IsSafeAssetName(string name)
        {
            if (string.IsNullOrEmpty(name) || name.Length > 128) return false;
            if (!name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) return false;
            if (name.IndexOf('/') >= 0 || name.IndexOf('\\') >= 0) return false;
            if (name.IndexOf("..", StringComparison.Ordinal) >= 0) return false;
            if (Path.IsPathRooted(name)) return false;
            return Path.GetFileName(name) == name;
        }

        private static string Encode(string value)
        {
            return Uri.EscapeDataString(value ?? "");
        }

        private async Task<string> FetchLatestTagAsync(CancellationToken cancellationToken)
        {
            try
            {
                using (var response = await _http.GetAsync(FreshUri(ApiLatest), cancellationToken).ConfigureAwait(false))
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
        public async Task<OtaManifest> FetchManifestForTagAsync(string tag, CancellationToken cancellationToken = default)
        {
            try
            {
                var uri = FreshUri(DownloadBase + Encode(tag) + "/versions.json");
                using (var response = await _http.GetAsync(uri, cancellationToken).ConfigureAwait(false))
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
        /// Compares the installed OTA build number against this runtime's
        /// cashier channel of the latest release manifest. Never throws. Any
        /// reachability, parse or channel problem sets
        /// <see cref="OtaCheckResult.Error"/> (UNAVAILABLE) - it is never
        /// silently reported as "up to date".
        /// </summary>
        public Task<OtaCheckResult> CheckForUpdateAsync(int currentBuild, CancellationToken cancellationToken = default)
        {
            return CheckForUpdateAsync(currentBuild, RuntimeChannel(), cancellationToken);
        }

        public async Task<OtaCheckResult> CheckForUpdateAsync(
            int currentBuild, string channelName, CancellationToken cancellationToken = default)
        {
            var unavailable = new OtaCheckResult { Current = currentBuild, Latest = currentBuild };
            var tag = await FetchLatestTagAsync(cancellationToken).ConfigureAwait(false);
            if (tag == null)
            {
                unavailable.Error = "network";
                return unavailable;
            }
            OtaManifest manifest;
            try
            {
                manifest = await FetchManifestForTagAsync(tag, cancellationToken).ConfigureAwait(false);
            }
            catch
            {
                manifest = null;
            }
            if (manifest == null)
            {
                unavailable.Error = "parse";
                return unavailable;
            }
            var channel = manifest.ForChannel(channelName);
            if (channel == null || channel.Version <= 0)
            {
                // Compatibility gate: this runtime's installer is not on the
                // release (yet). Unavailable, not "up to date".
                unavailable.Error = "no_compatible_channel";
                unavailable.ReleaseTag = tag;
                return unavailable;
            }
            return new OtaCheckResult
            {
                Current = currentBuild,
                Latest = channel.Version,
                NeedsUpdate = channel.Version > currentBuild,
                Channel = channel,
                ReleaseTag = tag,
            };
        }

        /// <summary>
        /// Downloads the installer for an offered update into
        /// <paramref name="targetDir"/> and verifies its SHA-256. Writes to a
        /// .part file first (removed in a finally on any failure) so an
        /// interrupted download is never mistaken for a finished one. Asset
        /// names are version-specific, so a verified file already on disk is
        /// a cache for exactly this version and is reused after a re-check of
        /// its digest. Does NOT start the installer - the caller owns the
        /// install step and must re-verify via
        /// <see cref="OtaVerifiedInstaller.Reverify"/> first.
        /// </summary>
        public async Task<OtaDownloadResult> DownloadLatestAsync(
            OtaCheckResult offered, string targetDir, IProgress<double> progress = null,
            CancellationToken cancellationToken = default)
        {
            var tag = offered == null ? null : offered.ReleaseTag;
            var channel = offered == null ? null : offered.Channel;
            if (string.IsNullOrEmpty(tag) || channel == null)
            {
                return new OtaDownloadResult { Error = "network" };
            }

            if (!IsSafeAssetName(channel.Asset))
            {
                return new OtaDownloadResult { Error = "invalid_asset" };
            }

            var expectedHash = (channel.Sha256 ?? "").Trim().ToLowerInvariant();
            if (expectedHash.Length == 0)
            {
                // A release without a published digest cannot be trusted.
                return new OtaDownloadResult { Error = "missing_checksum" };
            }

            var target = Path.Combine(targetDir, channel.Asset);
            var partial = target + ".part";
            try
            {
                Directory.CreateDirectory(targetDir);
                if (File.Exists(target) && new FileInfo(target).Length > 0)
                {
                    // Version-keyed cache: verify before reusing.
                    if (await VerifySha256Async(target, expectedHash, cancellationToken).ConfigureAwait(false))
                    {
                        if (progress != null) progress.Report(1.0);
                        return new OtaDownloadResult { Installer = HoldVerified(target, expectedHash) };
                    }
                    try { File.Delete(target); } catch { }
                }

                using (var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken))
                {
                    deadline.CancelAfter(BodyDeadline);
                    var token = deadline.Token;
                    var uri = new Uri(DownloadBase + Encode(tag) + "/" + Encode(channel.Asset));
                    using (var response = await _http
                        .GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, token)
                        .ConfigureAwait(false))
                    {
                        if (!response.IsSuccessStatusCode) return new OtaDownloadResult { Error = "network" };
                        var total = response.Content.Headers.ContentLength;
                        if (total.HasValue && total.Value > _maxInstallerBytes)
                        {
                            return new OtaDownloadResult { Error = "too_large" };
                        }
                        using (var input = await response.Content.ReadAsStreamAsync().ConfigureAwait(false))
                        using (var output = new FileStream(partial, FileMode.Create, FileAccess.Write, FileShare.None))
                        {
                            var buffer = new byte[81920];
                            long received = 0;
                            int read;
                            while ((read = await input.ReadAsync(buffer, 0, buffer.Length, token).ConfigureAwait(false)) > 0)
                            {
                                await output.WriteAsync(buffer, 0, read, token).ConfigureAwait(false);
                                received += read;
                                if (received > _maxInstallerBytes)
                                {
                                    return new OtaDownloadResult { Error = "too_large" };
                                }
                                if (progress != null && total.HasValue && total.Value > 0)
                                {
                                    progress.Report(Math.Min(1.0, (double)received / total.Value));
                                }
                            }
                        }
                    }
                    File.Move(partial, target);
                }

                if (!await VerifySha256Async(target, expectedHash, cancellationToken).ConfigureAwait(false))
                {
                    // Tampered or truncated artifact: delete it and refuse.
                    try { File.Delete(target); } catch { }
                    return new OtaDownloadResult { Error = "checksum_mismatch" };
                }

                if (progress != null) progress.Report(1.0);
                return new OtaDownloadResult { Installer = HoldVerified(target, expectedHash) };
            }
            catch (OperationCanceledException)
            {
                return new OtaDownloadResult { Error = "cancelled" };
            }
            catch
            {
                return new OtaDownloadResult { Error = "network" };
            }
            finally
            {
                // An abandoned partial download must never survive.
                try { if (File.Exists(partial)) File.Delete(partial); } catch { }
            }
        }

        private static OtaVerifiedInstaller HoldVerified(string file, string expectedHash)
        {
            var bytes = File.ReadAllBytes(file);
            return new OtaVerifiedInstaller(file, expectedHash, bytes);
        }

        /// <summary>Streams a file through SHA-256 and compares with the expected hex digest.</summary>
        public static async Task<bool> VerifySha256Async(
            string path, string expected, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrEmpty(expected) || expected.Length != 64) return false;
            using (var sha = SHA256.Create())
            using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                var hash = await Task.Run(() => sha.ComputeHash(stream), cancellationToken).ConfigureAwait(false);
                var hex = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
                return hex == expected.ToLowerInvariant();
            }
        }
    }
}
