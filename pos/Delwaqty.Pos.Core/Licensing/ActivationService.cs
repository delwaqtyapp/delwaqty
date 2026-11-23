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
        /// <summary>
        /// The app flavor this state was sealed under (pharmacy/retail).
        /// Sealed with the rest of the state (review #116 follow-up): a seal
        /// written by another flavor never restores here.
        /// </summary>
        public string Flavor;

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
    ///   identity (LocalLicenseSeal.SealState); v1 seals (partial payload,
    ///   unsigned StateJson) are never restored — they force one online
    ///   re-activation so every stored field is server-verified.
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
            parsed.State.Flavor = _flavor; // bound into the sealed state (#116)

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
            // Upgrade from the pre-#116 flat layout when the legacy root seal's
            // HMAC-VERIFIED payload names this same merchant (different
            // merchant: leave the old files untouched — they are that
            // merchant's archive). Only the verified payload is trusted; the
            // unsigned v1 StateJson is never read (review #115 follow-up).
            var legacyMerchant = TryReadLegacyMerchantId();
            if (legacyMerchant != null && legacyMerchant == parsed.State.MerchantId)
            {
                MerchantScope.MigrateLegacyRootData(_rootDir, newScope);
            }
            _scopeDir = newScope;
            Directory.CreateDirectory(_scopeDir);
            Persist(parsed.State, session);
            WriteActiveScopePointer(_scopeDir);
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
        /// device or flavor. Offline grace evaluation is the caller's job
        /// (LicenseGuard).
        ///
        /// Scope selection (review #116 follow-up): the active scope is the
        /// one named by the explicit active-scope pointer written at
        /// activation; archived scopes (previous merchants, other flavors)
        /// are NEVER auto-selected as the logged-in identity. The pointer is
        /// verified against the seal's canonical path (scope dir must equal
        /// ScopeDirFor(state.MerchantId)) and the current flavor (the sealed
        /// state carries its flavor).
        ///
        /// Legacy v1 seals (partial HMAC over a payload, unsigned StateJson)
        /// are NOT restored or re-sealed: their unsigned fields (Pro, ExpiresAt,
        /// MerchantId) were forgeable (review #115 follow-up), so a v1 install
        /// must re-activate ONLINE once — the fresh verified state is then
        /// sealed as v2. Only the v1 HMAC-verified payload's merchant id is
        /// read, and only to migrate that merchant's legacy data files on
        /// successful re-activation.
        /// </summary>
        public ActivationState Restore()
        {
            var pointer = ReadActiveScopePointer();
            if (pointer != null)
            {
                // An EMPTY pointer is the explicit signed-out marker
                // (Deactivate): archived seals are never auto-selected.
                if (pointer.Length == 0) return null;
                // Explicit active scope: restore exactly this one, never scan.
                var state = TryRestoreSealed(Path.Combine(pointer, "license.seal"));
                if (state != null && IsCanonicalScope(pointer, state))
                {
                    _scopeDir = pointer;
                    return state;
                }
                return null; // pointer present but seal gone/invalid: reactivate
            }
            // Pre-pointer installs: consider only current-flavor scopes whose
            // seal verifies AND whose path is canonical for the sealed state.
            ActivationState best = null;
            string bestScope = null;
            foreach (var scope in MerchantScope.ExistingScopes(_rootDir))
            {
                var state = TryRestoreSealed(Path.Combine(scope, "license.seal"));
                if (state != null && IsCanonicalScope(scope, state) &&
                    (best == null || state.ValidatedAtUtc > best.ValidatedAtUtc))
                {
                    best = state;
                    bestScope = scope;
                }
            }
            if (best != null)
            {
                _scopeDir = bestScope;
                WriteActiveScopePointer(bestScope);
                return best;
            }
            // A legacy v1 seal is deliberately NOT restored here: it requires
            // a fresh online activation (see class remarks).
            return null;
        }

        /// <summary>
        /// The scope dir must be exactly ScopeDirFor(state.MerchantId) for the
        /// CURRENT flavor, and the sealed state must carry that same flavor.
        /// </summary>
        private bool IsCanonicalScope(string scope, ActivationState state)
        {
            if (state.MerchantId == null) return false;
            if (!string.Equals(state.Flavor ?? "", _flavor, StringComparison.OrdinalIgnoreCase))
                return false;
            return string.Equals(Path.GetFullPath(scope),
                Path.GetFullPath(ScopeDirFor(state.MerchantId)), StringComparison.OrdinalIgnoreCase);
        }

        private string ActiveScopePointerPath { get { return Path.Combine(_rootDir, "active.scope"); } }

        private void WriteActiveScopePointer(string scopeDir)
        {
            try { File.WriteAllText(ActiveScopePointerPath, Path.GetFullPath(scopeDir)); }
            catch { /* pointer loss only forces one re-activation */ }
        }

        /// <summary>
        /// null = no pointer file (pre-pointer install, scan fallback allowed);
        /// "" = explicit signed-out marker (never scan); otherwise the scope path.
        /// </summary>
        private string ReadActiveScopePointer()
        {
            try
            {
                if (!File.Exists(ActiveScopePointerPath)) return null;
                return (File.ReadAllText(ActiveScopePointerPath) ?? "").Trim();
            }
            catch { return null; }
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
        /// Read ONLY the merchant id from a legacy v1 seal at the data root,
        /// and only from its HMAC-verified payload. The unsigned v1 StateJson
        /// is never deserialized or trusted (review #115 follow-up): its
        /// Pro/ExpiresAt/MerchantId fields were forgeable. A v1 install must
        /// re-activate online; this id exists only so a SAME-merchant
        /// re-activation can migrate the legacy data files.
        /// Payload layout: id|merchantId|plan|expiry|deviceId|validatedAt.
        /// </summary>
        private string TryReadLegacyMerchantId()
        {
            var path = Path.Combine(_rootDir, "license.seal");
            if (!File.Exists(path)) return null;
            try
            {
                var file = JsonSerializer.Deserialize<SealFile>(File.ReadAllText(path));
                if (file == null || file.Payload == null || file.Seal == null) return null;
                if (!LocalLicenseSeal.Verify(file.Payload, file.Seal, _deviceKey)) return null;
                var f = file.Payload.Split('|');
                return f.Length >= 2 && f[1].Length > 0 ? f[1] : null;
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

        /// <summary>
        /// Remove local activation (move to a new PC / sign out). Clears ALL
        /// active authorization: the active-scope pointer, the active scope's
        /// seal and its session credential (review #116 follow-up — deleting
        /// only the seal let an archived merchant's seal auto-restore at the
        /// next startup). Archived scopes' data files stay on disk, but no
        /// archive is ever selected as the logged-in identity.
        /// </summary>
        public void Deactivate()
        {
            // Empty pointer = signed out: the scan fallback must stay off so
            // no archived seal can become the identity at the next startup.
            File.WriteAllText(ActiveScopePointerPath, "");
            if (File.Exists(SealPath)) File.Delete(SealPath);
            SealedCredentialStore.Clear(CredentialPath);
            _scopeDir = null;
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
