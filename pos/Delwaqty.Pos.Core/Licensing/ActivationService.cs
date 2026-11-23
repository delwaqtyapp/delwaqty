using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Delwaqty.Pos.Core.Auth;
using Delwaqty.Pos.Core.Protection;
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
    ///
    /// Review fixes folded in:
    /// - #114: the device key is DPAPI-protected (DeviceKeyStore) and the
    ///   refresh token is DPAPI-sealed (SealedCredentialStore v2); legacy
    ///   plaintext-key / XOR files migrate on first read.
    /// - #115: the seal covers the FULL serialized state, bound to the device
    ///   identity (LocalLicenseSeal.SealState); v1 seals (partial payload)
    ///   are verified once and upgraded.
    /// - #116: all per-merchant files live in a merchant+flavor scope dir
    ///   (MerchantScope); activating a different merchant is refused while a
    ///   previous merchant still has unsynced outbox ops.
    /// </summary>
    public sealed class ActivationService
    {
        private readonly string _rootDir;
        private readonly string _flavor;
        private readonly byte[] _deviceKey;
        private readonly ILocalProtector _protector;
        private string _scopeDir;   // set by Restore()/ActivateAsync()

        public ActivationService(string rootDir, string flavor, ILocalProtector protector = null)
        {
            _rootDir = rootDir;
            _flavor = (flavor ?? "").Trim().ToLowerInvariant();
            Directory.CreateDirectory(rootDir);
            _protector = protector;
            _deviceKey = DeviceKeyStore.GetOrCreate(rootDir, protector);
        }

        public byte[] DeviceKey { get { return _deviceKey; } }
        public string RootDir { get { return _rootDir; } }
        public string LocalDeviceId { get { return DeviceId.GetOrCreate(_rootDir); } }

        /// <summary>The active merchant's scope dir (valid after Restore/Activate).</summary>
        public string CurrentScopeDir { get { return _scopeDir; } }

        public string ScopeDirFor(string merchantId)
        {
            return MerchantScope.ScopeDir(_rootDir, merchantId, _flavor);
        }

        public string SealPath
        {
            get
            {
                return _scopeDir != null
                    ? Path.Combine(_scopeDir, "license.seal")
                    : Path.Combine(_rootDir, "license.seal"); // legacy location
            }
        }

        public string CredentialPath
        {
            get
            {
                return _scopeDir != null
                    ? Path.Combine(_scopeDir, "session.cred")
                    : Path.Combine(_rootDir, "session.cred");
            }
        }

        private ILocalProtector CredProtector
        {
            get { return _protector ?? LocalProtector.ForPurpose("session-cred"); }
        }

        public sealed class ActivateResult
        {
            public bool Ok;
            public string Reason;           // UNKNOWN_KEY | BOUND_TO_OTHER_DEVICE | EXPIRED | OTHER_MERCHANT_DATA_PENDING | ...
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

            // #116: never let merchant B inherit merchant A's pending queue.
            var newScope = ScopeDirFor(parsed.State.MerchantId);
            var blocker = MerchantScope.ScopeWithPendingOps(_rootDir, newScope);
            if (blocker != null)
            {
                return new ActivateResult
                {
                    Ok = false,
                    Reason = "OTHER_MERCHANT_DATA_PENDING",
                    Error = blocker,
                };
            }
            // Upgrade from the pre-#116 flat layout when the legacy root seal
            // belongs to this same merchant (different merchant: leave the old
            // files untouched — they are that merchant's archive).
            var legacyState = TryRestoreLegacy(out _);
            if (legacyState != null && legacyState.MerchantId == parsed.State.MerchantId)
            {
                MerchantScope.MigrateLegacyRootData(_rootDir, newScope);
            }
            _scopeDir = newScope;
            Directory.CreateDirectory(_scopeDir);
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

        private sealed class SealFile
        {
            public int Version { get; set; }
            public string Payload { get; set; }   // v1 only
            public string Seal { get; set; }
            public string StateJson { get; set; }
        }

        private static readonly JsonSerializerOptions FieldJson =
            new JsonSerializerOptions { IncludeFields = true };

        private void Persist(ActivationState state, AuthSession session)
        {
            WriteSeal(state);
            if (session != null)
                SealedCredentialStore.Save(CredentialPath, session.RefreshToken, session.Email, CredProtector);
        }

        /// <summary>Re-seal a mutated state (periodic license refresh, #119).</summary>
        public void Reseal(ActivationState state)
        {
            WriteSeal(state);
        }

        private void WriteSeal(ActivationState state)
        {
            if (_scopeDir == null && state != null && state.MerchantId != null)
            {
                _scopeDir = ScopeDirFor(state.MerchantId);
                Directory.CreateDirectory(_scopeDir);
            }
            var stateJson = JsonSerializer.Serialize(state, FieldJson);
            // #115: the HMAC covers the entire serialized state and the device id.
            File.WriteAllText(SealPath, JsonSerializer.Serialize(new SealFile
            {
                Version = 2,
                Seal = LocalLicenseSeal.SealState(stateJson, LocalDeviceId, _deviceKey),
                StateJson = stateJson,
            }));
        }

        /// <summary>
        /// Restore a previously activated state. Returns null when there is no
        /// seal, the seal does not verify, or the state belongs to another
        /// device. Offline grace evaluation is the caller's job (LicenseGuard).
        /// </summary>
        public ActivationState Restore()
        {
            // Current layout: exactly one scope should hold a seal; if several
            // do (merchant switch with fully-synced data), take the most
            // recently validated one.
            ActivationState best = null;
            string bestScope = null;
            foreach (var scope in MerchantScope.ExistingScopes(_rootDir))
            {
                var state = TryRestoreSealed(Path.Combine(scope, "license.seal"));
                if (state != null && (best == null || state.ValidatedAtUtc > best.ValidatedAtUtc))
                {
                    best = state;
                    bestScope = scope;
                }
            }
            if (best != null)
            {
                _scopeDir = bestScope;
                return best;
            }
            // Upgrade path for the pre-#116 flat layout.
            var legacy = TryRestoreLegacy(out var migratedOk);
            if (legacy != null && migratedOk)
            {
                var scope = ScopeDirFor(legacy.MerchantId);
                MerchantScope.MigrateLegacyRootData(_rootDir, scope);
                _scopeDir = scope;
                WriteSeal(legacy); // reseal as v2 inside the scope dir
                // Re-save the credentials as v2 under the scope dir.
                string rt, email;
                var legacyCred = Path.Combine(scope, "session.cred");
                if (SealedCredentialStore.TryLoadLegacy(legacyCred, _deviceKey, out rt, out email))
                    SealedCredentialStore.Save(legacyCred, rt, email, CredProtector);
            }
            return legacy;
        }

        private ActivationState TryRestoreSealed(string path)
        {
            if (!File.Exists(path)) return null;
            try
            {
                var file = JsonSerializer.Deserialize<SealFile>(File.ReadAllText(path));
                if (file == null || file.StateJson == null) return null;
                if (file.Version != 2) return null; // v1 handled by TryRestoreLegacy
                var deviceId = LocalDeviceId;
                if (!LocalLicenseSeal.VerifyState(file.StateJson, deviceId, file.Seal, _deviceKey))
                    return null;
                var state = JsonSerializer.Deserialize<ActivationState>(file.StateJson, FieldJson);
                // The seal already binds deviceId; this is defense in depth
                // against a hand-crafted file sealed on another install whose
                // device.id was copied along.
                if (state == null ||
                    !string.Equals(state.DeviceId, deviceId, StringComparison.OrdinalIgnoreCase))
                    return null;
                return state;
            }
            catch { return null; }
        }

        /// <summary>
        /// Read the legacy v1 seal at the data root (partial HMAC payload).
        /// migratedOk is false when the seal parses but fails verification.
        /// </summary>
        private ActivationState TryRestoreLegacy(out bool migratedOk)
        {
            migratedOk = false;
            var path = Path.Combine(_rootDir, "license.seal");
            if (!File.Exists(path)) return null;
            try
            {
                var file = JsonSerializer.Deserialize<SealFile>(File.ReadAllText(path));
                if (file == null || file.StateJson == null || file.Payload == null) return null;
                if (!LocalLicenseSeal.Verify(file.Payload, file.Seal, _deviceKey)) return null;
                migratedOk = true;
                return JsonSerializer.Deserialize<ActivationState>(file.StateJson, FieldJson);
            }
            catch { return null; }
        }

        public bool TryLoadRefreshToken(out string refreshToken, out string email)
        {
            if (SealedCredentialStore.TryLoad(CredentialPath, CredProtector, out refreshToken, out email))
                return true;
            // v1 (XOR) file left behind by an older build: read once, migrate.
            if (SealedCredentialStore.TryLoadLegacy(CredentialPath, _deviceKey, out refreshToken, out email))
            {
                SealedCredentialStore.Save(CredentialPath, refreshToken, email, CredProtector);
                return true;
            }
            return false;
        }

        public void SaveRefreshToken(string refreshToken, string email)
        {
            SealedCredentialStore.Save(CredentialPath, refreshToken, email, CredProtector);
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
