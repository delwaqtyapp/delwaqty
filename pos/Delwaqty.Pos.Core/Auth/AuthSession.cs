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
    /// Persists the refresh token next to the other app data, XOR-obfuscated
    /// with the device key so the file is useless on another PC.
    /// Format: base64( XOR(utf8 payload, deviceKey repeated) ).
    /// Payload: refreshToken + "\n" + email.
    /// </summary>
    public static class SealedCredentialStore
    {
        public static void Save(string path, string refreshToken, string email, byte[] deviceKey)
        {
            var payload = (refreshToken ?? "") + "\n" + (email ?? "");
            var bytes = Encoding.UTF8.GetBytes(payload);
            for (var i = 0; i < bytes.Length; i++) bytes[i] ^= deviceKey[i % deviceKey.Length];
            File.WriteAllText(path, Convert.ToBase64String(bytes));
        }

        public static bool TryLoad(string path, byte[] deviceKey, out string refreshToken, out string email)
        {
            refreshToken = null; email = null;
            if (!File.Exists(path)) return false;
            byte[] bytes;
            try { bytes = Convert.FromBase64String(File.ReadAllText(path).Trim()); }
            catch { return false; }
            for (var i = 0; i < bytes.Length; i++) bytes[i] ^= deviceKey[i % deviceKey.Length];
            var payload = Encoding.UTF8.GetString(bytes);
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
