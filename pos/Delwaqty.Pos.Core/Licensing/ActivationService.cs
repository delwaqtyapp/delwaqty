using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Delwaqty.Pos.Core.Auth;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Core.Licensing
{
    /// <summary>Everything the app needs to configure itself after activation.</summary>
    public sealed class ActivationState
    {
        public string LicenseKey;
        public string Plan;
        public bool Pro;
        public string Status;              // active | expired | suspended ...
        public DateTimeOffset? ExpiresAt;
        public DateTimeOffset? GraceUntil;
        public string MerchantId;
        public string MerchantName;
        public string MerchantType;        // pharmacy | grocery | ... (drives the flavor)
        public string MerchantPhone;
        public string MerchantAddress;
        public string DeviceId;
        public DateTimeOffset ValidatedAtUtc;

        public bool IsPharmacy
        {
            get { return string.Equals(MerchantType, "pharmacy", StringComparison.OrdinalIgnoreCase); }
        }
    }

    /// <summary>
    /// Activation flow per pos/docs/license-activation-e2e.md:
    /// sign the merchant in, call cashier_device_link (binds the device on
    /// first contact), seal the result locally so restarts need no prompt and
    /// offline periods work inside the grace window.
    /// </summary>
    public sealed class ActivationService
    {
        private readonly string _dataDir;
        private readonly byte[] _deviceKey;

        public ActivationService(string dataDir)
        {
            _dataDir = dataDir;
            Directory.CreateDirectory(dataDir);
            var keyPath = Path.Combine(dataDir, "device.key");
            if (File.Exists(keyPath))
            {
                _deviceKey = Convert.FromBase64String(File.ReadAllText(keyPath).Trim());
            }
            else
            {
                _deviceKey = LocalLicenseSeal.NewDeviceKey();
                File.WriteAllText(keyPath, Convert.ToBase64String(_deviceKey));
            }
        }

        public byte[] DeviceKey { get { return _deviceKey; } }
        public string SealPath { get { return Path.Combine(_dataDir, "license.seal"); } }
        public string CredentialPath { get { return Path.Combine(_dataDir, "session.cred"); } }

        public sealed class ActivateResult
        {
            public bool Ok;
            public string Reason;           // UNKNOWN_KEY | BOUND_TO_OTHER_DEVICE | EXPIRED | ...
            public ActivationState State;
            public string Error;
        }

        /// <summary>Full online activation: auth + device link + local seal.</summary>
        public async Task<ActivateResult> ActivateAsync(
            AuthClient auth, SyncClient sync, string email, string password,
            string licenseKey, string deviceId)
        {
            AuthSession session;
            try { session = await auth.SignInPassword(email, password).ConfigureAwait(false); }
            catch (Exception ex)
            {
                return new ActivateResult { Ok = false, Reason = "AUTH_FAILED", Error = ex.Message };
            }
            sync.AccessToken = session.AccessToken;
            string linkJson;
            try { linkJson = await sync.DeviceLink(licenseKey, deviceId).ConfigureAwait(false); }
            catch (Exception ex)
            {
                return new ActivateResult { Ok = false, Reason = "NETWORK", Error = ex.Message };
            }
            var parsed = ParseDeviceLink(linkJson, licenseKey, deviceId);
            if (!parsed.Ok) return parsed;
            Persist(parsed.State, session);
            return parsed;
        }

        /// <summary>Parse a cashier_device_link response into an ActivationState.</summary>
        public static ActivateResult ParseDeviceLink(string linkJson, string licenseKey, string deviceId)
        {
            try
            {
                using (var doc = JsonDocument.Parse(linkJson))
                {
                    var root = doc.RootElement;
                    if (!root.TryGetProperty("ok", out var okEl) || !okEl.GetBoolean())
                    {
                        return new ActivateResult
                        {
                            Ok = false,
                            Reason = root.TryGetProperty("reason", out var r) ? r.GetString() : "UNKNOWN",
                        };
                    }
                    var state = new ActivationState
                    {
                        LicenseKey = licenseKey,
                        DeviceId = deviceId,
                        Plan = Str(root, "plan"),
                        Pro = root.TryGetProperty("pro", out var p) && p.ValueKind == JsonValueKind.True,
                        Status = Str(root, "status"),
                        ExpiresAt = Date(root, "expires_at"),
                        GraceUntil = Date(root, "grace_until"),
                        ValidatedAtUtc = DateTimeOffset.UtcNow,
                    };
                    if (root.TryGetProperty("merchant", out var m) && m.ValueKind == JsonValueKind.Object)
                    {
                        state.MerchantId = Str(m, "id");
                        state.MerchantName = Str(m, "name");
                        state.MerchantType = Str(m, "type");
                        state.MerchantPhone = Str(m, "phone");
                        state.MerchantAddress = Str(m, "address");
                    }
                    return new ActivateResult { Ok = true, State = state };
                }
            }
            catch (Exception ex)
            {
                return new ActivateResult { Ok = false, Reason = "BAD_RESPONSE", Error = ex.Message };
            }
        }

        private void Persist(ActivationState state, AuthSession session)
        {
            var info = new LicenseInfo
            {
                Id = "",
                MerchantId = state.MerchantId ?? "",
                Plan = state.Plan ?? "",
                ExpiresAt = state.ExpiresAt,
            };
            LicenseInfo parsed;
            string err;
            if (LicenseKey.TryParse(state.LicenseKey, out parsed, out err)) info = parsed;
            var payload = LocalLicenseSeal.StatePayload(info, state.DeviceId, state.ValidatedAtUtc);
            var seal = LocalLicenseSeal.Seal(payload, _deviceKey);
            // IncludeFields: ActivationState uses public fields, which STJ skips by default.
            File.WriteAllText(SealPath, JsonSerializer.Serialize(new SealFile
            {
                Payload = payload,
                Seal = seal,
                StateJson = JsonSerializer.Serialize(state, FieldJson),
            }));
            SealedCredentialStore.Save(CredentialPath, session.RefreshToken, session.Email, _deviceKey);
        }

        private sealed class SealFile
        {
            public string Payload { get; set; }
            public string Seal { get; set; }
            public string StateJson { get; set; }
        }

        private static readonly JsonSerializerOptions FieldJson =
            new JsonSerializerOptions { IncludeFields = true };

        /// <summary>
        /// Restore a previously activated state. Returns null when there is no
        /// seal or the seal does not match this device (copied data dir).
        /// Offline grace evaluation is the caller's job (LicenseEvaluator).
        /// </summary>
        public ActivationState Restore()
        {
            if (!File.Exists(SealPath)) return null;
            try
            {
                var file = JsonSerializer.Deserialize<SealFile>(File.ReadAllText(SealPath));
                if (file == null || !LocalLicenseSeal.Verify(file.Payload, file.Seal, _deviceKey)) return null;
                return JsonSerializer.Deserialize<ActivationState>(file.StateJson, FieldJson);
            }
            catch { return null; }
        }

        public bool TryLoadRefreshToken(out string refreshToken, out string email)
        {
            return SealedCredentialStore.TryLoad(CredentialPath, _deviceKey, out refreshToken, out email);
        }

        public void SaveRefreshToken(string refreshToken, string email)
        {
            SealedCredentialStore.Save(CredentialPath, refreshToken, email, _deviceKey);
        }

        /// <summary>Remove local activation (move to a new PC / sign out). Local sales data stays.</summary>
        public void Deactivate()
        {
            if (File.Exists(SealPath)) File.Delete(SealPath);
            SealedCredentialStore.Clear(CredentialPath);
        }

        private static string Str(JsonElement el, string name)
        {
            return el.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        }

        private static DateTimeOffset? Date(JsonElement el, string name)
        {
            var s = Str(el, name);
            DateTimeOffset dto;
            if (s != null && DateTimeOffset.TryParse(s, out dto)) return dto;
            return null;
        }
    }
}
