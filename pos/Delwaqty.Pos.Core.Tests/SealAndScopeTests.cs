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
        public void Dispose() { Directory.Delete(_dir, true); }

        private static ActivationState SampleState(string deviceId)
        {
            return new ActivationState
            {
                LicenseKey = "DLWQ1.x.y", Plan = "core_annual", Pro = true, Status = "active",
                ExpiresAt = DateTimeOffset.UtcNow.AddMonths(6),
                GraceUntil = DateTimeOffset.UtcNow.AddMonths(6).AddDays(3),
                MerchantId = "m-1", MerchantName = "صيدلية الشفاء", MerchantType = "pharmacy",
                DeviceId = deviceId, ValidatedAtUtc = DateTimeOffset.UtcNow,
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

        [Fact]
        public void Legacy_V1_Flat_Layout_Migrates_Into_Scope_And_V2()
        {
            // Build the pre-#116 flat layout by hand: v1 seal + XOR creds +
            // loose outbox.db at the data root.
            var svc = new ActivationService(_dir, "Pharmacy");
            var deviceId = svc.LocalDeviceId;
            var state = SampleState(deviceId);
            var info = new LicenseInfo
            {
                Id = Guid.NewGuid().ToString(), MerchantId = "m-1", Plan = "core_annual",
                ExpiresAt = state.ExpiresAt,
            };
            var payload = LocalLicenseSeal.StatePayload(info, deviceId, state.ValidatedAtUtc);
            var stateJson = System.Text.Json.JsonSerializer.Serialize(state,
                new System.Text.Json.JsonSerializerOptions { IncludeFields = true });
            File.WriteAllText(Path.Combine(_dir, "license.seal"),
                "{\"Payload\":" + System.Text.Json.JsonSerializer.Serialize(payload) +
                ",\"Seal\":\"" + LocalLicenseSeal.Seal(payload, svc.DeviceKey) +
                "\",\"StateJson\":" + System.Text.Json.JsonSerializer.Serialize(stateJson) + "}");
            var credBytes = System.Text.Encoding.UTF8.GetBytes("rt-legacy\nm@example.com");
            for (var i = 0; i < credBytes.Length; i++) credBytes[i] ^= svc.DeviceKey[i % svc.DeviceKey.Length];
            File.WriteAllText(Path.Combine(_dir, "session.cred"), Convert.ToBase64String(credBytes));
            using (var store = new OutboxStore(Path.Combine(_dir, "outbox.db")))
                store.Enqueue(OutboxPayloads.Customer("احمد", "010", null));

            var restored = svc.Restore();
            Assert.NotNull(restored);
            Assert.Equal("m-1", restored.MerchantId);
            Assert.NotNull(svc.CurrentScopeDir);
            // Root files moved into the scope; the pending outbox op survives.
            Assert.False(File.Exists(Path.Combine(_dir, "outbox.db")));
            Assert.True(File.Exists(Path.Combine(svc.CurrentScopeDir, "outbox.db")));
            using (var scoped = new OutboxStore(Path.Combine(svc.CurrentScopeDir, "outbox.db")))
                Assert.Equal(1, scoped.PendingCount());
            // Seal re-written as v2 inside the scope and verifies.
            var sealText = File.ReadAllText(Path.Combine(svc.CurrentScopeDir, "license.seal"));
            Assert.Contains("\"Version\":2", sealText);
            Assert.NotNull(new ActivationService(_dir, "Pharmacy").Restore());
            // Credentials upgraded to v2 (DPAPI marker).
            Assert.True(svc.TryLoadRefreshToken(out var rt, out _));
            Assert.Equal("rt-legacy", rt);
            Assert.StartsWith(SealedCredentialStore.BlobPrefix,
                File.ReadAllText(Path.Combine(svc.CurrentScopeDir, "session.cred")));
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

            // A legacy plaintext key is migrated on first read.
            var dir2 = Path.Combine(Path.GetTempPath(), "key-" + Guid.NewGuid());
            Directory.CreateDirectory(dir2);
            try
            {
                var legacy = LocalLicenseSeal.NewDeviceKey();
                File.WriteAllText(Path.Combine(dir2, "device.key"), Convert.ToBase64String(legacy));
                var loaded = Protection.DeviceKeyStore.GetOrCreate(dir2);
                Assert.Equal(legacy, loaded);
                Assert.StartsWith(Protection.DeviceKeyStore.BlobPrefix,
                    File.ReadAllText(Path.Combine(dir2, "device.key")));
            }
            finally { Directory.Delete(dir2, true); }
        }

    }
}
