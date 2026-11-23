using System;
using System.IO;
using System.Net;
using System.Net.Http;
using Delwaqty.Pos.Core.Auth;
using Delwaqty.Pos.Core.Licensing;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class AuthTests
    {
        [Fact]
        public async System.Threading.Tasks.Task SignIn_Parses_Tokens()
        {
            var stub = new StubHandler().Ok(
                "{\"access_token\":\"at-1\",\"refresh_token\":\"rt-1\",\"expires_in\":3600," +
                "\"user\":{\"id\":\"u-1\",\"email\":\"m@example.com\"}}");
            var auth = new AuthClient("https://x.supabase.co", "anon", new HttpClient(stub));
            var session = await auth.SignInPassword("m@example.com", "pw");
            Assert.Equal("at-1", session.AccessToken);
            Assert.Equal("rt-1", session.RefreshToken);
            Assert.Equal("u-1", session.UserId);
            Assert.False(session.IsExpired(DateTimeOffset.UtcNow));
            Assert.Contains("grant_type=password", stub.Requests[0].Url);
        }

        [Fact]
        public async System.Threading.Tasks.Task SignIn_Error_Surfaces_Server_Message()
        {
            var stub = new StubHandler().Respond(HttpStatusCode.BadRequest,
                "{\"error\":\"invalid_grant\",\"error_description\":\"Invalid login credentials\"}");
            var auth = new AuthClient("https://x.supabase.co", "anon", new HttpClient(stub));
            var ex = await Assert.ThrowsAsync<InvalidOperationException>(
                () => auth.SignInPassword("m@example.com", "wrong"));
            Assert.Contains("Invalid login credentials", ex.Message);
        }

        [Fact]
        public void Sealed_Credentials_V2_Roundtrip_And_Legacy_Xor_Still_Reads()
        {
            var dir = Path.Combine(Path.GetTempPath(), "cred-" + Guid.NewGuid());
            Directory.CreateDirectory(dir);
            try
            {
                var path = Path.Combine(dir, "s.cred");
                var protector = TestProtector.New();
                SealedCredentialStore.Save(path, "rt-abc", "m@example.com", protector);
                Assert.True(SealedCredentialStore.TryLoad(path, protector, out var rt, out var email));
                Assert.Equal("rt-abc", rt);
                Assert.Equal("m@example.com", email);
                // A copied file on another PC (different machine key) must not decode.
                var foreign = TestProtector.New();
                Assert.False(SealedCredentialStore.TryLoad(path, foreign, out var rt2, out _) && rt2 == "rt-abc");
                // The v2 file carries the DPAPI marker.
                Assert.StartsWith(SealedCredentialStore.BlobPrefix, File.ReadAllText(path));

                // Legacy v1 (XOR with the device key) still loads through the
                // legacy reader, and the v2 loader never mistakes it for v2.
                var legacyPath = Path.Combine(dir, "legacy.cred");
                var deviceKey = LocalLicenseSeal.NewDeviceKey();
                var payload = System.Text.Encoding.UTF8.GetBytes("rt-old\nm@example.com");
                for (var i = 0; i < payload.Length; i++) payload[i] ^= deviceKey[i % deviceKey.Length];
                File.WriteAllText(legacyPath, Convert.ToBase64String(payload));
                Assert.False(SealedCredentialStore.TryLoad(legacyPath, protector, out _, out _));
                Assert.True(SealedCredentialStore.TryLoadLegacy(legacyPath, deviceKey, out var rtOld, out _));
                Assert.Equal("rt-old", rtOld);
            }
            finally { Directory.Delete(dir, true); }
        }
    }

    public class ActivationTests : IDisposable
    {
        private readonly string _dir = Path.Combine(Path.GetTempPath(), "act-" + Guid.NewGuid());
        public ActivationTests() { Directory.CreateDirectory(_dir); }
        public void Dispose() { Directory.Delete(_dir, true); }

        private const string LinkOk =
            "{\"ok\":true,\"plan\":\"trial\",\"pro\":false,\"status\":\"active\"," +
            "\"expires_at\":\"2026-12-22 00:00:00+00\",\"grace_until\":\"2026-12-25 00:00:00+00\"," +
            "\"merchant\":{\"id\":\"m-1\",\"name\":\"صيدلية الشفاء\",\"type\":\"pharmacy\"," +
            "\"phone\":\"010\",\"address\":\"ميت غمر\"},\"product_count\":42}";

        [Fact]
        public void Parse_DeviceLink_Ok_Reads_Merchant_And_Plan()
        {
            var r = ActivationService.ParseDeviceLink(LinkOk, "DLWQ1.x.y", "dev-1");
            Assert.True(r.Ok);
            Assert.Equal("trial", r.State.Plan);
            Assert.False(r.State.Pro);
            Assert.Equal("صيدلية الشفاء", r.State.MerchantName);
            Assert.True(r.State.IsPharmacy);
            Assert.Equal(new DateTimeOffset(2026, 12, 22, 0, 0, 0, TimeSpan.Zero), r.State.ExpiresAt);
        }

        [Fact]
        public void Parse_DeviceLink_Error_Reasons_Pass_Through()
        {
            foreach (var reason in new[] { "UNKNOWN_KEY", "BOUND_TO_OTHER_DEVICE", "SUSPENDED", "EXPIRED" })
            {
                var r = ActivationService.ParseDeviceLink(
                    "{\"ok\":false,\"reason\":\"" + reason + "\"}", "k", "d");
                Assert.False(r.Ok);
                Assert.Equal(reason, r.Reason);
            }
        }

        private static string MakeTrialKey()
        {
            return "DLWQ1." + LicenseKey.Base64UrlEncode(
                System.Text.Encoding.UTF8.GetBytes(
                    Guid.NewGuid() + "|" + Guid.NewGuid() + "|trial|2026-12-22 00:00:00+00")) + "." +
                new string('a', 64);
        }

        [Fact]
        public async System.Threading.Tasks.Task Activate_Then_Restore_Roundtrips()
        {
            var stub = new StubHandler()
                .Ok("{\"access_token\":\"at\",\"refresh_token\":\"rt\",\"expires_in\":3600,\"user\":{\"id\":\"u\"}}")
                .Ok(LinkOk);
            var http = new HttpClient(stub);
            var auth = new AuthClient("https://x.supabase.co", "anon", http);
            var sync = new SyncClient("https://x.supabase.co", "anon", http);
            var svc = new ActivationService(_dir, "Pharmacy");
            var deviceId = svc.LocalDeviceId;
            var res = await svc.ActivateAsync(auth, sync, "m@example.com", "pw", MakeTrialKey(), deviceId);
            Assert.True(res.Ok, res.Reason + " " + res.Error);
            // device_link was called with the key and device id
            Assert.Contains("cashier_device_link", stub.Requests[1].Url);
            Assert.Contains(deviceId, stub.Requests[1].Body);

            // Data lives in the merchant+flavor scope dir (#116), not the root.
            Assert.NotNull(svc.CurrentScopeDir);
            Assert.Contains("m-1", svc.CurrentScopeDir);
            Assert.Contains("pharmacy", svc.CurrentScopeDir);

            var restored = svc.Restore();
            Assert.NotNull(restored);
            Assert.Equal("صيدلية الشفاء", restored.MerchantName);
            Assert.Equal("trial", restored.Plan);
            Assert.True(svc.TryLoadRefreshToken(out var rt, out _));
            Assert.Equal("rt", rt);
        }

        [Fact]
        public void Restore_Rejects_A_Tampered_Or_Foreign_Seal()
        {
            var svc = new ActivationService(_dir, "Pharmacy");
            File.WriteAllText(svc.SealPath,
                "{\"Payload\":\"a|b|trial|lifetime|dev|2026-01-01\",\"Seal\":\"" + new string('0', 64) +
                "\",\"StateJson\":\"{}\"}");
            Assert.Null(svc.Restore());

            // #115: a v2 file whose StateJson was edited by hand (Pro flipped)
            // is rejected — the seal covers the WHOLE serialized state.
            var scope = svc.ScopeDirFor("m-9");
            Directory.CreateDirectory(scope);
            var state = new ActivationState
            {
                LicenseKey = "k", Plan = "trial", Pro = true, Status = "active",
                MerchantId = "m-9", MerchantType = "pharmacy", DeviceId = svc.LocalDeviceId,
                ValidatedAtUtc = DateTimeOffset.UtcNow,
            };
            var json = System.Text.Json.JsonSerializer.Serialize(state,
                new System.Text.Json.JsonSerializerOptions { IncludeFields = true });
            File.WriteAllText(Path.Combine(scope, "license.seal"),
                "{\"Version\":2,\"Seal\":\"" + new string('0', 64) + "\",\"StateJson\":" +
                System.Text.Json.JsonSerializer.Serialize(json) + "}");
            Assert.Null(svc.Restore());
        }

        [Fact]
        public void DeviceId_Is_Stable_Per_DataDir()
        {
            var a = DeviceId.GetOrCreate(_dir);
            var b = DeviceId.GetOrCreate(_dir);
            Assert.Equal(a, b);
            var other = Path.Combine(Path.GetTempPath(), "dev-" + Guid.NewGuid());
            var c = DeviceId.GetOrCreate(other);
            Assert.NotEqual(a, c);
            Directory.Delete(other, true);
        }
    }
}
