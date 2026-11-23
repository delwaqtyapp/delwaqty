using System;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

namespace Delwaqty.Pos.Core.Licensing
{
    /// <summary>Parsed DLWQ1 license key issued by cashier_license_issue (migration 340).</summary>
    public sealed class LicenseInfo
    {
        public string Id;
        public string MerchantId;
        public string Plan;
        public DateTimeOffset? ExpiresAt; // null = lifetime
        public string SignatureHex;
        public string RawPayload;
    }

    public static class LicenseKey
    {
        public const string Prefix = "DLWQ1";

        private static readonly string[] TimestampFormats =
        {
            "yyyy-MM-dd HH:mm:ss.FFFFFFzzz",
            "yyyy-MM-dd HH:mm:ss.FFFFFFzz",
            "yyyy-MM-dd HH:mm:sszzz",
            "yyyy-MM-dd HH:mm:sszz",
        };

        public static bool TryParse(string key, out LicenseInfo info, out string error)
        {
            info = null; error = null;
            if (string.IsNullOrWhiteSpace(key)) { error = "EMPTY_KEY"; return false; }
            var parts = key.Trim().Split('.');
            // DLWQ1.<payload>.<sig> -- payload itself contains no dots (base64url keeps '=').
            if (parts.Length != 3 || parts[0] != Prefix) { error = "BAD_FORMAT"; return false; }
            string payload;
            try { payload = Encoding.UTF8.GetString(Base64UrlDecode(parts[1])); }
            catch { error = "BAD_PAYLOAD_ENCODING"; return false; }
            var f = payload.Split('|');
            if (f.Length != 4) { error = "BAD_PAYLOAD"; return false; }
            Guid tmp;
            if (!Guid.TryParse(f[0], out tmp)) { error = "BAD_ID"; return false; }
            if (!Guid.TryParse(f[1], out tmp)) { error = "BAD_MERCHANT"; return false; }
            DateTimeOffset? expires = null;
            if (f[3] != "lifetime")
            {
                DateTimeOffset dto;
                if (!DateTimeOffset.TryParseExact(f[3], TimestampFormats, CultureInfo.InvariantCulture,
                        DateTimeStyles.None, out dto)
                    && !DateTimeOffset.TryParse(f[3], CultureInfo.InvariantCulture,
                        DateTimeStyles.AssumeUniversal, out dto))
                { error = "BAD_EXPIRY"; return false; }
                expires = dto;
            }
            if (!IsHex(parts[2]) || parts[2].Length != 64) { error = "BAD_SIGNATURE"; return false; }
            info = new LicenseInfo
            {
                Id = f[0], MerchantId = f[1], Plan = f[2],
                ExpiresAt = expires, SignatureHex = parts[2].ToLowerInvariant(),
                RawPayload = payload,
            };
            return true;
        }

        public static byte[] Base64UrlDecode(string s)
        {
            var b = s.Replace('-', '+').Replace('_', '/');
            switch (b.Length % 4) { case 2: b += "=="; break; case 3: b += "="; break; }
            return Convert.FromBase64String(b);
        }

        public static string Base64UrlEncode(byte[] bytes)
        {
            return Convert.ToBase64String(bytes).Replace('+', '-').Replace('/', '_');
        }

        private static bool IsHex(string s)
        {
            foreach (var c in s)
                if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) return false;
            return true;
        }
    }

    /// <summary>
    /// Offline license guard. The server HMAC key never leaves the database, so the
    /// client cannot re-verify the server signature offline. Instead, after a
    /// successful online validation the app seals the license state with a random
    /// device key it generates and stores locally; offline startup checks the seal.
    /// This stops casual key copying between machines, which is the real threat in
    /// the Egyptian one-time-license market.
    /// </summary>
    public static class LocalLicenseSeal
    {
        public static byte[] NewDeviceKey()
        {
            var key = new byte[32];
            using (var rng = RandomNumberGenerator.Create()) rng.GetBytes(key);
            return key;
        }

        public static string Seal(string statePayload, byte[] deviceKey)
        {
            using (var h = new HMACSHA256(deviceKey))
                return ToHex(h.ComputeHash(Encoding.UTF8.GetBytes(statePayload)));
        }

        public static bool Verify(string statePayload, string expectedSealHex, byte[] deviceKey)
        {
            if (string.IsNullOrEmpty(expectedSealHex)) return false;
            var actual = Seal(statePayload, deviceKey);
            return string.Equals(actual, expectedSealHex.ToLowerInvariant(), StringComparison.Ordinal);
        }

        public static string StatePayload(LicenseInfo info, string deviceId, DateTimeOffset validatedAtUtc)
        {
            var exp = info.ExpiresAt.HasValue ? info.ExpiresAt.Value.UtcDateTime.ToString("o") : "lifetime";
            return info.Id + "|" + info.MerchantId + "|" + info.Plan + "|" + exp + "|" +
                   deviceId + "|" + validatedAtUtc.UtcDateTime.ToString("o");
        }

        // ---- v2: the WHOLE serialized activation state is sealed (review
        // #115). v1 covered only a subset of fields, so Pro/ExpiresAt/
        // MerchantId in the stored StateJson were forgeable by anyone who
        // could read the device key. v2 binds the exact stored JSON to the
        // device identity; any byte changed invalidates the seal.
        public const string SealV2Prefix = "DELWQ-SEAL-v2";

        public static string SealState(string stateJson, string deviceId, byte[] deviceKey)
        {
            using (var h = new HMACSHA256(deviceKey))
            {
                var input = SealV2Prefix + "|" + (deviceId ?? "") + "|" + (stateJson ?? "");
                return ToHex(h.ComputeHash(Encoding.UTF8.GetBytes(input)));
            }
        }

        public static bool VerifyState(string stateJson, string deviceId, string expectedSealHex, byte[] deviceKey)
        {
            if (string.IsNullOrEmpty(expectedSealHex)) return false;
            var actual = SealState(stateJson, deviceId, deviceKey);
            return string.Equals(actual, expectedSealHex.ToLowerInvariant(), StringComparison.Ordinal);
        }

        private static string ToHex(byte[] bytes)
        {
            var sb = new StringBuilder(bytes.Length * 2);
            foreach (var b in bytes) sb.Append(b.ToString("x2"));
            return sb.ToString();
        }
    }

    public enum LicenseStatus { Active, Trial, ExpiredInGrace, Expired, Suspended, Unknown }

    public static class LicenseEvaluator
    {
        /// <summary>Offline status from the sealed state, mirroring the server rules.</summary>
        public static LicenseStatus Evaluate(LicenseInfo info, DateTimeOffset nowUtc, int graceDays)
        {
            if (info == null) return LicenseStatus.Unknown;
            if (!info.ExpiresAt.HasValue) return info.Plan == "trial" ? LicenseStatus.Trial : LicenseStatus.Active;
            if (info.ExpiresAt.Value >= nowUtc)
                return info.Plan == "trial" ? LicenseStatus.Trial : LicenseStatus.Active;
            if (info.ExpiresAt.Value.AddDays(graceDays) >= nowUtc) return LicenseStatus.ExpiredInGrace;
            return LicenseStatus.Expired;
        }
    }
}
