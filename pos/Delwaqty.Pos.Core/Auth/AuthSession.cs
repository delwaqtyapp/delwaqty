using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Delwaqty.Pos.Core.Auth
{
    /// <summary>
    /// Supabase auth for the cashier app. The cashier RPCs all require an
    /// authenticated merchant owner (auth.uid() + is_merchant_owner), so the
    /// app signs in with the merchant's platform email/password, keeps the
    /// access token in memory, and stores the refresh token locally
    /// obfuscated with the per-install device key. The obfuscation stops
    /// casual copying of the session file to another machine; it is not
    /// encryption against an attacker who owns the PC.
    /// </summary>
    public sealed class AuthSession
    {
        public string AccessToken;
        public string RefreshToken;
        public DateTimeOffset ExpiresAtUtc;
        public string UserId;
        public string Email;

        public bool IsExpired(DateTimeOffset nowUtc)
        {
            return string.IsNullOrEmpty(AccessToken) || nowUtc >= ExpiresAtUtc.AddMinutes(-1);
        }
    }

    public sealed class AuthClient
    {
        private readonly HttpClient _http;
        private readonly string _baseUrl;
        private readonly string _anonKey;

        public AuthClient(string baseUrl, string anonKey, HttpClient http = null)
        {
            _baseUrl = baseUrl.TrimEnd('/');
            _anonKey = anonKey;
            _http = http ?? new HttpClient();
        }

        public Task<AuthSession> SignInPassword(string email, string password)
        {
            var body = JsonSerializer.Serialize(new Dictionary<string, object>
            { ["email"] = email, ["password"] = password });
            return TokenRequest(_baseUrl + "/auth/v1/token?grant_type=password", body);
        }

        public Task<AuthSession> Refresh(string refreshToken)
        {
            var body = JsonSerializer.Serialize(new Dictionary<string, object>
            { ["refresh_token"] = refreshToken });
            return TokenRequest(_baseUrl + "/auth/v1/token?grant_type=refresh_token", body);
        }

        private async Task<AuthSession> TokenRequest(string url, string bodyJson)
        {
            using (var req = new HttpRequestMessage(HttpMethod.Post, url))
            {
                req.Headers.Add("apikey", _anonKey);
                req.Content = new StringContent(bodyJson, Encoding.UTF8, "application/json");
                using (var res = await _http.SendAsync(req).ConfigureAwait(false))
                {
                    var text = await res.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!res.IsSuccessStatusCode)
                    {
                        string msg = null;
                        try
                        {
                            using (var err = JsonDocument.Parse(text))
                            {
                                if (err.RootElement.TryGetProperty("error_description", out var d)) msg = d.GetString();
                                else if (err.RootElement.TryGetProperty("msg", out var m)) msg = m.GetString();
                            }
                        }
                        catch { /* keep generic */ }
                        throw new InvalidOperationException(
                            "auth failed: " + (int)res.StatusCode + (msg != null ? " " + msg : ""));
                    }
                    using (var doc = JsonDocument.Parse(text))
                    {
                        var root = doc.RootElement;
                        var expiresIn = root.TryGetProperty("expires_in", out var ex) && ex.ValueKind == JsonValueKind.Number
                            ? ex.GetInt32() : 3600;
                        var session = new AuthSession
                        {
                            AccessToken = GetStr(root, "access_token"),
                            RefreshToken = GetStr(root, "refresh_token"),
                            ExpiresAtUtc = DateTimeOffset.UtcNow.AddSeconds(expiresIn),
                        };
                        if (root.TryGetProperty("user", out var user) && user.ValueKind == JsonValueKind.Object)
                        {
                            session.UserId = GetStr(user, "id");
                            session.Email = GetStr(user, "email");
                        }
                        if (string.IsNullOrEmpty(session.AccessToken) || string.IsNullOrEmpty(session.RefreshToken))
                            throw new InvalidOperationException("auth response missing tokens");
                        return session;
                    }
                }
            }
        }

        private static string GetStr(JsonElement el, string name)
        {
            return el.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        }
    }

    /// <summary>
    /// Persists the refresh token next to the other app data (review #114).
    ///
    /// v2 (current): DPAPI CurrentUser via ILocalProtector — the blob only
    /// unprotects on this PC; a copied data dir is useless elsewhere.
    /// File format: "DP2:" + base64(protect(utf8 payload)).
    /// Payload: refreshToken + "\n" + email.
    ///
    /// v1 (legacy, read-only): base64( XOR(utf8 payload, deviceKey repeated) ).
    /// v1 files are migrated to v2 on first successful load.
    /// </summary>
    public static class SealedCredentialStore
    {
        public const string BlobPrefix = "DP2:";

        public static void Save(string path, string refreshToken, string email,
            Protection.ILocalProtector protector)
        {
            var payload = (refreshToken ?? "") + "\n" + (email ?? "");
            var blob = protector.Protect(Encoding.UTF8.GetBytes(payload));
            File.WriteAllText(path, BlobPrefix + Convert.ToBase64String(blob));
        }

        public static bool TryLoad(string path, Protection.ILocalProtector protector,
            out string refreshToken, out string email)
        {
            refreshToken = null; email = null;
            if (!File.Exists(path)) return false;
            string text;
            try { text = (File.ReadAllText(path) ?? "").Trim(); }
            catch { return false; }
            if (!text.StartsWith(BlobPrefix, StringComparison.Ordinal)) return false;
            byte[] bytes;
            try { bytes = protector.Unprotect(Convert.FromBase64String(text.Substring(BlobPrefix.Length))); }
            catch { return false; } // foreign PC / wrong entropy
            return Split(Encoding.UTF8.GetString(bytes), out refreshToken, out email);
        }

        /// <summary>Read a legacy v1 (XOR with device key) credential file.</summary>
        public static bool TryLoadLegacy(string path, byte[] deviceKey, out string refreshToken, out string email)
        {
            refreshToken = null; email = null;
            if (!File.Exists(path)) return false;
            string text;
            try { text = (File.ReadAllText(path) ?? "").Trim(); }
            catch { return false; }
            if (text.StartsWith(BlobPrefix, StringComparison.Ordinal)) return false;
            byte[] bytes;
            try { bytes = Convert.FromBase64String(text); }
            catch { return false; }
            for (var i = 0; i < bytes.Length; i++) bytes[i] ^= deviceKey[i % deviceKey.Length];
            return Split(Encoding.UTF8.GetString(bytes), out refreshToken, out email);
        }

        private static bool Split(string payload, out string refreshToken, out string email)
        {
            refreshToken = null; email = null;
            var nl = payload.IndexOf('\n');
            if (nl < 0) return false;
            refreshToken = payload.Substring(0, nl);
            email = payload.Substring(nl + 1);
            return refreshToken.Length > 0;
        }

        public static void Clear(string path)
        {
            if (File.Exists(path)) File.Delete(path);
        }
    }
}
