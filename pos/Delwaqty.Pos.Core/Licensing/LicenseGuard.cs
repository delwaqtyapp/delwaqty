using System;
using System.Threading.Tasks;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Core.Licensing
{
    /// <summary>What the app may do under the current license state.</summary>
    public enum PosMode
    {
        /// <summary>Selling, stock ops and sync all allowed.</summary>
        Full,
        /// <summary>Expired but inside the grace window: everything still works.</summary>
        Grace,
        /// <summary>
        /// Suspended, revoked, unknown, or expired past the offline cutoff:
        /// selling and stock mutations stop; local data is preserved and the
        /// outbox keeps syncing (review #119: a clear offline cutoff that
        /// preserves unsynced data).
        /// </summary>
        Locked,
    }

    /// <summary>
    /// Offline license mode decision, mirroring the server rules
    /// (cashier_license_validate / cashier_device_link: grace_days default 3).
    ///
    /// Fail-closed policy (review #119 follow-up): the status string is an
    /// explicit allowlist. Only "active"/"trial" sell freely; "expired" is
    /// evaluated against the clock (grace window); everything else —
    /// suspended, revoked, unknown, missing — locks. A lifetime license
    /// (no expires_at) is only honoured for an allowlisted active status:
    /// an unknown status with no expiry is Locked, never Full.
    /// </summary>
    public static class LicenseGuard
    {
        public const int DefaultGraceDays = 3;

        /// <summary>Statuses that may sell (subject to the expiry clock).</summary>
        public static readonly string[] ActiveStatuses = { "active", "trial" };

        /// <summary>Statuses that are evaluated against the expiry clock.</summary>
        public static readonly string[] ClockStatuses = { "active", "trial", "expired" };

        public static PosMode Evaluate(ActivationState state, DateTimeOffset nowUtc)
        {
            if (state == null) return PosMode.Locked;
            var status = (state.Status ?? "").Trim().ToLowerInvariant();
            var clocked = false;
            foreach (var s in ClockStatuses) if (status == s) { clocked = true; break; }
            if (!clocked) return PosMode.Locked; // suspended/revoked/unknown/missing: fail closed
            if (!state.ExpiresAt.HasValue)
            {
                // Lifetime: only genuinely active statuses are Full.
                foreach (var s in ActiveStatuses) if (status == s) return PosMode.Full;
                return PosMode.Locked;
            }
            if (nowUtc <= state.ExpiresAt.Value) return PosMode.Full;
            var graceEnd = state.GraceUntil ?? state.ExpiresAt.Value.AddDays(DefaultGraceDays);
            return nowUtc <= graceEnd ? PosMode.Grace : PosMode.Locked;
        }
    }

    /// <summary>
    /// Periodic verified license refresh (review #119: enforcement used to
    /// happen only at startup, so a suspension never reached a running app).
    /// Re-runs cashier_device_link on a schedule, merges the verified state
    /// and reseals it locally.
    ///
    /// Network failure is transient: the sealed state is kept and the guard's
    /// clock/grace cutoff applies. An authoritative NEGATIVE answer
    /// (SUSPENDED, EXPIRED, UNKNOWN_KEY, BOUND_TO_OTHER_DEVICE, ...) is not:
    /// the state is marked revoked/suspended/expired, resealed, and the app
    /// locks (review #119 follow-up).
    /// </summary>
    public sealed class LicenseRefresher
    {
        private readonly Licensing.ActivationService _activation;
        private readonly SyncClient _sync;

        public static readonly TimeSpan DefaultInterval = TimeSpan.FromHours(12);

        public LicenseRefresher(ActivationService activation, SyncClient sync)
        {
            _activation = activation;
            _sync = sync;
        }

        public sealed class RefreshResult
        {
            public bool Contacted;         // server answered
            public bool Changed;           // state changed and was resealed
            public string Reason;          // set on ok:false (SUSPENDED, EXPIRED, ...)
            public PosMode Mode;           // mode after the refresh
        }

        /// <summary>
        /// Refresh when the last verified contact is older than interval.
        /// Mutates and reseals state on change; returns null when skipped.
        /// Callers must STILL re-run LicenseGuard.Evaluate on a skip/null:
        /// the clock moves even when the network is not asked (review #119).
        /// </summary>
        public async Task<RefreshResult> RefreshAsync(ActivationState state, DateTimeOffset nowUtc, TimeSpan? interval = null)
        {
            if (state == null) return null;
            if (nowUtc - state.ValidatedAtUtc < (interval ?? DefaultInterval)) return null;

            var result = new RefreshResult();
            string linkJson;
            try
            {
                linkJson = await _sync.DeviceLink(state.LicenseKey, state.DeviceId).ConfigureAwait(false);
            }
            catch
            {
                // Transient network failure: keep the sealed state; the
                // guard's grace cutoff still applies via the clock.
                result.Mode = LicenseGuard.Evaluate(state, nowUtc);
                return result;
            }
            result.Contacted = true;

            var parsed = ActivationService.ParseDeviceLink(linkJson, state.LicenseKey, state.DeviceId);
            if (!parsed.Ok)
            {
                // Authoritative denial from the server — fail closed.
                result.Reason = parsed.Reason;
                if (string.Equals(parsed.Reason, "SUSPENDED", StringComparison.OrdinalIgnoreCase))
                    state.Status = "suspended";
                else if (string.Equals(parsed.Reason, "EXPIRED", StringComparison.OrdinalIgnoreCase))
                    state.Status = "expired";
                else
                    // UNKNOWN_KEY, BOUND_TO_OTHER_DEVICE, or any other verified
                    // negative: the server no longer honours this activation.
                    state.Status = "revoked";
                _activation.Reseal(state);
                result.Changed = true;
                result.Mode = LicenseGuard.Evaluate(state, nowUtc);
                return result;
            }

            var fresh = parsed.State;
            if (fresh.Plan != state.Plan || fresh.Pro != state.Pro ||
                fresh.Status != state.Status || fresh.ExpiresAt != state.ExpiresAt ||
                fresh.GraceUntil != state.GraceUntil)
            {
                state.Plan = fresh.Plan;
                state.Pro = fresh.Pro;
                state.Status = fresh.Status;
                state.ExpiresAt = fresh.ExpiresAt;
                state.GraceUntil = fresh.GraceUntil;
                result.Changed = true;
            }
            state.ValidatedAtUtc = nowUtc;
            _activation.Reseal(state); // always: ValidatedAtUtc moved
            result.Changed = true;
            result.Mode = LicenseGuard.Evaluate(state, nowUtc);
            return result;
        }
    }
}
