using System;
using System.IO;
using Delwaqty.Pos.Core.Auth;
using Delwaqty.Pos.Core.Licensing;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>#115: full-state device-bound seal + v1 upgrade. #116: scoping.</summary>
    public class SealAndScopeTests : IDisposable
    {
        private readonly string _dir = Path.Combine(Path.GetTempPath(), "seal-" + Guid.NewGuid());
        public SealAndScopeTests() { Directory.CreateDirectory(_dir); }
        public void Dispose() { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); Directory.Delete(_dir, true); }

        private static ActivationState SampleState(string deviceId)
        {
            return new ActivationState
            {
                LicenseKey = "DLWQ1.x.y", Plan = "core_annual", Pro = true, Status = "active",
                ExpiresAt = DateTimeOffset.UtcNow.AddMonths(6),
                GraceUntil = DateTimeOffset.UtcNow.AddMonths(6).AddDays(3),
                MerchantId = "m-1", MerchantName = "صيدلية الشفاء", MerchantType = "pharmacy",
                DeviceId = deviceId, ValidatedAtUtc = DateTimeOffset.UtcNow,
                Flavor = "pharmacy",
            };
        }

        [Fact]
        public void Seal_V2_Covers_Every_Field_And_Binds_Device()
        {
            var svc = new ActivationService(_dir, "Pharmacy");
            var scope = svc.ScopeDirFor("m-1");
            Directory.CreateDirectory(scope);
            // Persist via reflection-free path: activate offline by writing through Reseal.
            var state = SampleState(svc.LocalDeviceId);
            svc.Reseal(state);

            var restored = svc.Restore();
            Assert.NotNull(restored);
            Assert.True(restored.Pro);
            Assert.Equal("m-1", restored.MerchantId);

            // Flip one field in the stored JSON without touching the seal.
            var text = File.ReadAllText(Path.Combine(scope, "license.seal"));
            var tampered = text.Replace("\"Pro\":true", "\"Pro\":false");
            if (tampered == text) tampered = text.Replace("m-1", "m-2");
            Assert.NotEqual(text, tampered);
            File.WriteAllText(Path.Combine(scope, "license.seal"), tampered);
            Assert.Null(new ActivationService(_dir, "Pharmacy").Restore());
        }

        [Fact]
        public void Seal_V2_Rejects_A_State_Sealed_For_Another_Device()
        {
            var svc = new ActivationService(_dir, "Pharmacy");
            var scope = svc.ScopeDirFor("m-1");
            Directory.CreateDirectory(scope);
            svc.Reseal(SampleState(svc.LocalDeviceId));

            // Simulate a copied data dir: someone rewrites device.id (the copy
            // brought a different one) — the state no longer matches.
            File.WriteAllText(Path.Combine(_dir, "device.id"), Guid.NewGuid().ToString("D"));
            Assert.Null(new ActivationService(_dir, "Pharmacy").Restore());
        }

        /// <summary>Build a legacy v1 flat-layout seal (valid payload HMAC).</summary>
        private string WriteLegacyV1Seal(ActivationService svc, ActivationState state)
        {
            var info = new LicenseInfo
            {
                Id = Guid.NewGuid().ToString(), MerchantId = state.MerchantId, Plan = state.Plan,
                ExpiresAt = state.ExpiresAt,
            };
            var payload = LocalLicenseSeal.StatePayload(info, state.DeviceId, state.ValidatedAtUtc);
            var stateJson = System.Text.Json.JsonSerializer.Serialize(state,
                new System.Text.Json.JsonSerializerOptions { IncludeFields = true });
            File.WriteAllText(Path.Combine(_dir, "license.seal"),
                "{\"Payload\":" + System.Text.Json.JsonSerializer.Serialize(payload) +
                ",\"Seal\":\"" + LocalLicenseSeal.Seal(payload, svc.DeviceKey) +
                "\",\"StateJson\":" + System.Text.Json.JsonSerializer.Serialize(stateJson) + "}");
            return payload;
        }

        [Fact]
        public void Legacy_V1_State_Is_Never_Restored_Or_Resealed()
        {
            // Review #115 follow-up: v1 keeps its unsigned StateJson — even a
            // PERFECTLY VALID v1 seal is not restored; the install must
            // re-activate online so every field is server-verified.
            var svc = new ActivationService(_dir, "Pharmacy");
            WriteLegacyV1Seal(svc, SampleState(svc.LocalDeviceId));
            using (var store = new OutboxStore(Path.Combine(_dir, "outbox.db")))
                store.Enqueue(OutboxPayloads.Customer("احمد", "010", null));

            Assert.Null(svc.Restore());
            Assert.Null(new ActivationService(_dir, "Pharmacy").Restore());
            // Nothing migrated, nothing re-sealed: the root files stay put.
            Assert.True(File.Exists(Path.Combine(_dir, "outbox.db")));
            Assert.True(File.Exists(Path.Combine(_dir, "license.seal")));
            Assert.False(Directory.Exists(Path.Combine(_dir, "merchants")));
            Assert.DoesNotContain("\"Version\":2",
                File.ReadAllText(Path.Combine(_dir, "license.seal")));
        }

        [Fact]
        public void Forged_Legacy_V1_State_Is_Rejected()
        {
            // The exact #115 attack: a valid v1 payload HMAC (the attacker
            // read the old plaintext device key) but a StateJson with Pro and
            // expiry forged. The forged fields must never reach a v2 seal.
            var svc = new ActivationService(_dir, "Pharmacy");
            var forged = SampleState(svc.LocalDeviceId);
            forged.Plan = "core_annual";       // payload says the same...
            WriteLegacyV1Seal(svc, forged);
            forged.Pro = true;                  // ...but the UNSIGNED state is forged
            forged.ExpiresAt = DateTimeOffset.UtcNow.AddYears(10);
            var stateJson = System.Text.Json.JsonSerializer.Serialize(forged,
                new System.Text.Json.JsonSerializerOptions { IncludeFields = true });
            var text = File.ReadAllText(Path.Combine(_dir, "license.seal"));
            var doc = System.Text.Json.JsonDocument.Parse(text);
            var payload = doc.RootElement.GetProperty("Payload").GetString();
            var seal = doc.RootElement.GetProperty("Seal").GetString();
            File.WriteAllText(Path.Combine(_dir, "license.seal"),
                "{\"Payload\":" + System.Text.Json.JsonSerializer.Serialize(payload) +
                ",\"Seal\":\"" + seal +
                "\",\"StateJson\":" + System.Text.Json.JsonSerializer.Serialize(stateJson) + "}");

            Assert.Null(svc.Restore());
            Assert.False(Directory.Exists(Path.Combine(_dir, "merchants")));
        }

        [Fact]
        public async System.Threading.Tasks.Task Legacy_V1_Data_Migrates_On_Online_Reactivation()
        {
            // The v1 install re-activates ONLINE with the same merchant: only
            // then do the legacy data files move into the scope, keyed by the
            // HMAC-verified payload merchant id — never by the unsigned state.
            var svc = new ActivationService(_dir, "Pharmacy");
            var state = SampleState(svc.LocalDeviceId);
            WriteLegacyV1Seal(svc, state);
            using (var store = new OutboxStore(Path.Combine(_dir, "outbox.db")))
                store.Enqueue(OutboxPayloads.Customer("احمد", "010", null));

            var stub = new StubHandler()
                .Ok("{\"access_token\":\"at\",\"refresh_token\":\"rt\",\"expires_in\":3600,\"user\":{\"id\":\"u\"}}")
                .Ok("{\"ok\":true,\"plan\":\"core_annual\",\"pro\":true,\"status\":\"active\"," +
                    "\"expires_at\":\"" + DateTimeOffset.UtcNow.AddMonths(6).ToString("yyyy-MM-dd HH:mm:ss+00") + "\"," +
                    "\"merchant\":{\"id\":\"m-1\",\"name\":\"صيدلية الشفاء\",\"type\":\"pharmacy\"}}");
            var http = new System.Net.Http.HttpClient(stub);
            var auth = new Auth.AuthClient("https://x.supabase.co", "anon", http);
            var sync = new SyncClient("https://x.supabase.co", "anon", http);
            var key = "DLWQ1." + LicenseKey.Base64UrlEncode(
                System.Text.Encoding.UTF8.GetBytes(Guid.NewGuid() + "|m-1|core_annual|lifetime")) +
                "." + new string('a', 64);
            var res = await svc.ActivateAsync(auth, sync, "m@example.com", "pw", key, svc.LocalDeviceId);

            Assert.True(res.Ok, res.Reason);
            Assert.False(File.Exists(Path.Combine(_dir, "outbox.db")));
            Assert.True(File.Exists(Path.Combine(svc.CurrentScopeDir, "outbox.db")));
            using (var scoped = new OutboxStore(Path.Combine(svc.CurrentScopeDir, "outbox.db")))
                Assert.Equal(1, scoped.PendingCount());
            Assert.NotNull(new ActivationService(_dir, "Pharmacy").Restore());
        }

        [Fact]
        public void Seal_From_Other_Flavor_Never_Restores()
        {
            // #116 follow-up: the flavor is part of the authenticated state —
            // a pharmacy install must not pick up a retail scope's seal.
            var svc = new ActivationService(_dir, "Pharmacy");
            var scope = svc.ScopeDirFor("m-1");
            Directory.CreateDirectory(scope);
            svc.Reseal(SampleState(svc.LocalDeviceId));

            var retail = new ActivationService(_dir, "Retail");
            Assert.Null(retail.Restore());
            // ...while the pharmacy service still restores it.
            Assert.NotNull(new ActivationService(_dir, "Pharmacy").Restore());
        }

        [Fact]
        public void Seal_In_Alien_Scope_Path_Never_Restores()
        {
            // A valid seal copied into a scope dir that does NOT match its
            // sealed merchant id is not selected (canonical path check).
            var svc = new ActivationService(_dir, "Pharmacy");
            var scope = svc.ScopeDirFor("m-1");
            Directory.CreateDirectory(scope);
            svc.Reseal(SampleState(svc.LocalDeviceId));
            var alien = Path.Combine(_dir, "merchants", "zzz-pharmacy");
            Directory.CreateDirectory(alien);
            File.Copy(Path.Combine(scope, "license.seal"), Path.Combine(alien, "license.seal"));
            File.Delete(Path.Combine(scope, "license.seal"));

            Assert.Null(new ActivationService(_dir, "Pharmacy").Restore());
        }

        [Fact]
        public void Deactivate_Clears_Pointer_So_No_Archive_Auto_Restores()
        {
            var svc = new ActivationService(_dir, "Pharmacy");
            var scope = svc.ScopeDirFor("m-1");
            Directory.CreateDirectory(scope);
            svc.Reseal(SampleState(svc.LocalDeviceId));
            Assert.NotNull(svc.Restore()); // writes the pointer

            // A second merchant's archive with a valid seal (old device state).
            var scopeB = svc.ScopeDirFor("m-2");
            Directory.CreateDirectory(scopeB);
            var svcB = new ActivationService(_dir, "Pharmacy");
            var stateB = SampleState(svcB.LocalDeviceId);
            stateB.MerchantId = "m-2";
            svcB.Reseal(stateB); // seals into m-2 scope via MerchantId

            svc.Deactivate();
            // Sign-out cleared the pointer AND the active seal: the archived
            // m-2 seal must not become the logged-in identity at startup.
            Assert.Null(new ActivationService(_dir, "Pharmacy").Restore());
        }

        [Fact]
        public void Cross_Merchant_Activation_Refused_While_Old_Queue_Pending()
        {
            // Merchant A's scope holds an unsynced outbox op.
            var svc = new ActivationService(_dir, "Pharmacy");
            var scopeA = svc.ScopeDirFor("m-A");
            Directory.CreateDirectory(scopeA);
            using (var store = new OutboxStore(Path.Combine(scopeA, "outbox.db")))
                store.Enqueue(OutboxPayloads.Customer("احمد", "010", null));

            // Activating merchant B must refuse; re-activating A is fine.
            Assert.Equal(scopeA, MerchantScope.ScopeWithPendingOps(_dir, svc.ScopeDirFor("m-B")));
            Assert.Null(MerchantScope.ScopeWithPendingOps(_dir, scopeA));
        }

        [Fact]
        public void Device_Key_File_Is_Protected_Not_Plaintext()
        {
            var svc = new ActivationService(_dir, "Pharmacy");
            var text = File.ReadAllText(Path.Combine(_dir, "device.key"));
            Assert.StartsWith(Protection.DeviceKeyStore.BlobPrefix, text);
            // Re-opening reads the same key through the protector.
            var again = new ActivationService(_dir, "Pharmacy");
            Assert.Equal(svc.DeviceKey, again.DeviceKey);

            // Plaintext content is NEVER adopted (review #115 follow-up) —
            // not even a genuine legacy key: the file is replaced with a
            // fresh protected key, old seals die, reactivation is forced.
            var dir2 = Path.Combine(Path.GetTempPath(), "key-" + Guid.NewGuid());
            Directory.CreateDirectory(dir2);
            try
            {
                var legacy = LocalLicenseSeal.NewDeviceKey();
                File.WriteAllText(Path.Combine(dir2, "device.key"), Convert.ToBase64String(legacy));
                var loaded = Protection.DeviceKeyStore.GetOrCreate(dir2);
                Assert.NotEqual(legacy, loaded);
                Assert.StartsWith(Protection.DeviceKeyStore.BlobPrefix,
                    File.ReadAllText(Path.Combine(dir2, "device.key")));
                // And it round-trips afterwards.
                Assert.Equal(loaded, Protection.DeviceKeyStore.GetOrCreate(dir2));
            }
            finally { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); Directory.Delete(dir2, true); }
        }

        [Fact]
        public void Planted_Legacy_Key_Is_Ignored_After_Migration()
        {
            // Review #114/#115 follow-up: a plaintext device.key planted by a
            // directory writer must NOT be adopted — adopting it would let
            // them forge seals. There is no marker file to delete anymore:
            // plaintext content is unconditionally replaced.
            var svc = new ActivationService(_dir, "Pharmacy");
            var original = svc.DeviceKey;

            var planted = LocalLicenseSeal.NewDeviceKey();
            File.WriteAllText(Path.Combine(_dir, "device.key"), Convert.ToBase64String(planted));
            var loaded = Protection.DeviceKeyStore.GetOrCreate(_dir);
            Assert.NotEqual(planted, loaded);   // regenerated, not adopted
            Assert.NotEqual(original, loaded);  // old seals die -> reactivation
            Assert.StartsWith(Protection.DeviceKeyStore.BlobPrefix,
                File.ReadAllText(Path.Combine(_dir, "device.key")));
        }

        [Fact]
        public void Key_Regeneration_Preserves_All_Other_Data()
        {
            // Device-key recovery flow (review follow-up): a regenerated key
            // kills the seals but every other byte stays — the outbox and
            // scopes survive for reactivation/sync.
            var svc = new ActivationService(_dir, "Pharmacy");
            var scope = svc.ScopeDirFor("m-1");
            Directory.CreateDirectory(scope);
            using (var store = new OutboxStore(Path.Combine(scope, "outbox.db")))
                store.Enqueue(OutboxPayloads.Customer("احمد", "010", null));

            File.WriteAllText(Path.Combine(_dir, "device.key"), Convert.ToBase64String(new byte[32]));
            var fresh = Protection.DeviceKeyStore.GetOrCreate(_dir);
            Assert.NotEqual(svc.DeviceKey, fresh);
            // Data untouched, outbox intact.
            Assert.True(File.Exists(Path.Combine(scope, "outbox.db")));
            using (var store = new OutboxStore(Path.Combine(scope, "outbox.db")))
                Assert.Equal(1, store.PendingCount());
        }

        private sealed class ThrowingProtector : Protection.ILocalProtector
        {
            public string Name { get { return "throwing"; } }
            public byte[] Protect(byte[] plain) { return (byte[])plain.Clone(); }
            public byte[] Unprotect(byte[] blob) { throw new System.Security.Cryptography.CryptographicException("foreign blob"); }
        }

        [Fact]
        public void Corrupt_Or_Foreign_Device_Key_Regenerates_Instead_Of_Crashing()
        {
            // Security review LOW-1: a device.key protected by another user /
            // machine (or corrupted) must not crash startup; the key is
            // regenerated, which invalidates old seals and forces reactivation.
            var dir2 = Path.Combine(Path.GetTempPath(), "key-" + Guid.NewGuid());
            Directory.CreateDirectory(dir2);
            try
            {
                var first = Protection.DeviceKeyStore.GetOrCreate(dir2, new ThrowingProtector());
                // Second read: unprotect throws -> regenerate.
                var second = Protection.DeviceKeyStore.GetOrCreate(dir2, new ThrowingProtector());
                Assert.NotEqual(first, second);
                Assert.StartsWith(Protection.DeviceKeyStore.BlobPrefix,
                    File.ReadAllText(Path.Combine(dir2, "device.key")));
            }
            finally { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); Directory.Delete(dir2, true); }
        }

        [Fact]
        public void Unreadable_Scope_Blocks_Activation_FailClosed()
        {
            // #116 follow-up: a scope whose database cannot be read may hold
            // unsynced ops — it must block cross-merchant activation, not be
            // silently ignored.
            var svc = new ActivationService(_dir, "Pharmacy");
            var scopeA = svc.ScopeDirFor("m-A");
            Directory.CreateDirectory(scopeA);
            File.WriteAllText(Path.Combine(scopeA, "pos.db"), "this is not sqlite");

            Assert.Equal(scopeA, MerchantScope.ScopeWithPendingOps(_dir, svc.ScopeDirFor("m-B")));
        }

    }
}
