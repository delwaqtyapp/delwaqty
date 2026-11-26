using System;
using System.IO;
using System.Net.Http;
using Delwaqty.Pos.Core.Licensing;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>
    /// #119: enforcement used to run only at startup; suspended was never
    /// checked; the offline cutoff was implicit. LicenseGuard decides the
    /// mode; LicenseRefresher re-verifies with the server periodically.
    /// </summary>
    public class LicenseGuardTests
    {
        private static ActivationState State(string status = "active", int expiresInDays = 10,
            bool lifetime = false)
        {
            return new ActivationState
            {
                LicenseKey = "k", Plan = "core_annual", Status = status,
                ExpiresAt = lifetime ? (DateTimeOffset?)null : DateTimeOffset.UtcNow.AddDays(expiresInDays),
                MerchantId = "m-1", MerchantType = "grocery", DeviceId = "dev-1",
                ValidatedAtUtc = DateTimeOffset.UtcNow,
            };
        }

        [Fact]
        public void Suspended_Is_Locked_Even_Before_Expiry()
        {
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(State(status: "suspended"), DateTimeOffset.UtcNow));
        }

        [Fact]
        public void Lifetime_Is_Full()
        {
            Assert.Equal(PosMode.Full, LicenseGuard.Evaluate(State(lifetime: true), DateTimeOffset.UtcNow));
        }

        [Fact]
        public void Active_Grace_And_Cutoff_Are_Explicit()
        {
            var now = DateTimeOffset.UtcNow;
            Assert.Equal(PosMode.Full, LicenseGuard.Evaluate(State(expiresInDays: 10), now));
            Assert.Equal(PosMode.Grace, LicenseGuard.Evaluate(State(expiresInDays: -1), now));
            // Default grace is 3 days past expiry.
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(State(expiresInDays: -4), now));
            // A server-provided grace_until wins over the default.
            var s = State(expiresInDays: -4);
            s.GraceUntil = now.AddDays(2);
            Assert.Equal(PosMode.Grace, LicenseGuard.Evaluate(s, now));
        }

        [Fact]
        public void Null_State_Is_Locked()
        {
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(null, DateTimeOffset.UtcNow));
        }

        [Fact]
        public void Unknown_Or_Revoked_Status_Is_Locked_Never_Full()
        {
            // #119 follow-up: fail closed on anything outside the allowlist —
            // an unknown status must not sell even with no expiry set.
            var now = DateTimeOffset.UtcNow;
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(State(status: "revoked"), now));
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(State(status: "whatever"), now));
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(State(status: ""), now));
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(State(status: null), now));
            Assert.Equal(PosMode.Locked,
                LicenseGuard.Evaluate(State(status: "whatever", lifetime: true), now));
            // 'expired' is clock-evaluated: grace window still applies.
            Assert.Equal(PosMode.Grace, LicenseGuard.Evaluate(State(status: "expired", expiresInDays: -1), now));
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(State(status: "expired", expiresInDays: -9), now));
            // ...but an 'expired' status with no expiry date cannot establish
            // a grace window: locked.
            Assert.Equal(PosMode.Locked,
                LicenseGuard.Evaluate(State(status: "expired", lifetime: true), now));
        }
    }

    public class LicenseRefresherTests : IDisposable
    {
        private readonly string _dir = Path.Combine(Path.GetTempPath(), "refresh-" + Guid.NewGuid());
        public LicenseRefresherTests() { Directory.CreateDirectory(_dir); }
        public void Dispose() { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); Directory.Delete(_dir, true); }

        private ActivationService NewActivatedService(StubHandler stub)
        {
            stub
                .Ok("{\"access_token\":\"at\",\"refresh_token\":\"rt\",\"expires_in\":3600,\"user\":{\"id\":\"u\"}}")
                .Ok("{\"ok\":true,\"plan\":\"trial\",\"pro\":false,\"status\":\"active\"," +
                    "\"expires_at\":\"" + DateTimeOffset.UtcNow.AddDays(5).ToString("yyyy-MM-dd HH:mm:ss+00") + "\"," +
                    "\"merchant\":{\"id\":\"m-1\",\"name\":\"ص\",\"type\":\"grocery\"}}");
            var http = new HttpClient(stub);
            var auth = new Auth.AuthClient("https://x.supabase.co", "anon", http);
            var sync = new SyncClient("https://x.supabase.co", "anon", http);
            var svc = new ActivationService(_dir, "Retail");
            var key = "DLWQ1." + LicenseKey.Base64UrlEncode(
                System.Text.Encoding.UTF8.GetBytes(
                    Guid.NewGuid() + "|" + Guid.NewGuid() + "|trial|lifetime")) + "." + new string('a', 64);
            var res = svc.ActivateAsync(auth, sync, "m@example.com", "pw", key, svc.LocalDeviceId).Result;
            Assert.True(res.Ok, res.Reason);
            return svc;
        }

        [Fact]
        public void Recent_Validation_Skips_The_Network()
        {
            var stub = new StubHandler();
            var svc = NewActivatedService(stub);
            var state = svc.Restore();
            var refresher = new LicenseRefresher(svc,
                new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub)));
            var before = stub.Requests.Count;
            var res = refresher.RefreshAsync(state, DateTimeOffset.UtcNow).Result;
            Assert.Null(res); // validated seconds ago: no refresh due
            Assert.Equal(before, stub.Requests.Count);
        }

        [Fact]
        public void Stale_State_Is_Reverified_And_Resealed()
        {
            var stub = new StubHandler();
            var svc = NewActivatedService(stub);
            var state = svc.Restore();
            state.ValidatedAtUtc = DateTimeOffset.UtcNow.AddDays(-2);

            stub.Ok("{\"ok\":true,\"plan\":\"core_annual\",\"pro\":true,\"status\":\"active\"," +
                "\"expires_at\":\"" + DateTimeOffset.UtcNow.AddDays(300).ToString("yyyy-MM-dd HH:mm:ss+00") + "\"," +
                "\"merchant\":{\"id\":\"m-1\",\"name\":\"ص\",\"type\":\"grocery\"}}");
            var refresher = new LicenseRefresher(svc,
                new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub)));
            var now = DateTimeOffset.UtcNow;
            var res = refresher.RefreshAsync(state, now).Result;

            Assert.True(res.Contacted);
            Assert.True(res.Changed);
            Assert.True(state.Pro);
            Assert.Equal("core_annual", state.Plan);
            Assert.Equal(now, state.ValidatedAtUtc);
            Assert.Equal(PosMode.Full, res.Mode);
            // The resealed state survives a cold restore (still #115-sealed).
            var restored = new ActivationService(_dir, "Retail").Restore();
            Assert.NotNull(restored);
            Assert.True(restored.Pro);
        }

        [Fact]
        public void Suspended_Verdict_Locks_Immediately()
        {
            var stub = new StubHandler();
            var svc = NewActivatedService(stub);
            var state = svc.Restore();
            state.ValidatedAtUtc = DateTimeOffset.UtcNow.AddDays(-2);

            stub.Ok("{\"ok\":false,\"reason\":\"SUSPENDED\"}");
            var refresher = new LicenseRefresher(svc,
                new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub)));
            var res = refresher.RefreshAsync(state, DateTimeOffset.UtcNow).Result;

            Assert.True(res.Contacted);
            Assert.Equal("SUSPENDED", res.Reason);
            Assert.Equal(PosMode.Locked, res.Mode);
            Assert.Equal("suspended", state.Status);
            // And the verdict persisted: a fresh restore stays locked.
            var restored = new ActivationService(_dir, "Retail").Restore();
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(restored, DateTimeOffset.UtcNow));
        }

        [Fact]
        public void Authoritative_Denial_Unknown_Key_Locks_And_Persists()
        {
            // #119 follow-up: UNKNOWN_KEY / BOUND_TO_OTHER_DEVICE are
            // authoritative denials, not transient errors — the app locks and
            // the verdict survives a restart.
            var stub = new StubHandler();
            var svc = NewActivatedService(stub);
            var state = svc.Restore();
            state.ValidatedAtUtc = DateTimeOffset.UtcNow.AddDays(-2);

            stub.Ok("{\"ok\":false,\"reason\":\"UNKNOWN_KEY\"}");
            var refresher = new LicenseRefresher(svc,
                new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub)));
            var res = refresher.RefreshAsync(state, DateTimeOffset.UtcNow).Result;

            Assert.True(res.Contacted);
            Assert.Equal(PosMode.Locked, res.Mode);
            Assert.Equal("revoked", state.Status);
            var restored = new ActivationService(_dir, "Retail").Restore();
            Assert.Equal(PosMode.Locked, LicenseGuard.Evaluate(restored, DateTimeOffset.UtcNow));
        }

        [Fact]
        public void Too_Many_Attempts_Is_Transient_State_Unchanged()
        {
            // #297: the server throttle must never revoke a running shop.
            var stub = new StubHandler();
            var svc = NewActivatedService(stub);
            var state = svc.Restore();
            var validated = DateTimeOffset.UtcNow.AddDays(-2);
            state.ValidatedAtUtc = validated;
            var statusBefore = state.Status;
            var modeBefore = LicenseGuard.Evaluate(state, DateTimeOffset.UtcNow);

            stub.Ok("{\"ok\":false,\"reason\":\"TOO_MANY_ATTEMPTS\"}");
            var refresher = new LicenseRefresher(svc,
                new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub)));
            var res = refresher.RefreshAsync(state, DateTimeOffset.UtcNow).Result;

            Assert.True(res.Contacted);
            Assert.False(res.Changed);
            Assert.Equal("TOO_MANY_ATTEMPTS", res.Reason);
            Assert.Equal(statusBefore, state.Status);
            Assert.Equal(validated, state.ValidatedAtUtc);
            Assert.Equal(modeBefore, res.Mode);
            Assert.NotEqual(PosMode.Locked, res.Mode);
            var restored = new ActivationService(_dir, "Retail").Restore();
            Assert.Equal(statusBefore, restored.Status);
            Assert.Equal(modeBefore, LicenseGuard.Evaluate(restored, DateTimeOffset.UtcNow));
        }

        [Fact]
        public void Offline_Keeps_Current_State_And_Grace_Still_Applies()
        {
            var stub = new StubHandler();
            var svc = NewActivatedService(stub);
            var state = svc.Restore();
            state.ValidatedAtUtc = DateTimeOffset.UtcNow.AddDays(-2);

            var refresher = new LicenseRefresher(svc,
                new SyncClient("https://x.supabase.co", "anon", new HttpClient(stub)));
            var res = refresher.RefreshAsync(state, DateTimeOffset.UtcNow).Result;
            Assert.False(res.Contacted);       // 404 -> treated as offline
            Assert.Equal(PosMode.Full, res.Mode); // still inside expiry
        }
    }
}
