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
        /// Suspended, or expired past the offline cutoff: selling and stock
        /// mutations stop; local data is preserved and the outbox keeps
        /// syncing (review #119: a clear offline cutoff that preserves
        /// unsynced data).
        /// </summary>
        Locked,
    }

    /// <summary>
    /// Offline license mode decision, mirroring the server rules
    /// (cashier_license_validate / cashier_device_link: grace_days default 3).
    /// </summary>
    public static class LicenseGuard
    {
        public const int DefaultGraceDays = 3;

        public static PosMode Evaluate(ActivationState state, DateTimeOffset nowUtc)
        {
            if (state == null) return PosMode.Locked;
            if (string.Equals(state.Status, "suspended", StringComparison.OrdinalIgnoreCase))
                return PosMode.Locked;
            if (!state.ExpiresAt.HasValue) return PosMode.Full; // lifetime
            if (nowUtc <= state.ExpiresAt.Value) return PosMode.Full;
            var graceEnd = state.GraceUntil ?? state.ExpiresAt.Value.AddDays(DefaultGraceDays);
            return nowUtc <= graceEnd ? PosMode.Grace : PosMode.Locked;
        }
    }

    /// <summary>
    /// Periodic verified license refresh (review #119: enforcement used to
    /// happen only at startup, so a suspension never reached a running app).
    /// Re-runs cashier_device_link on a schedule, merges the verified state
    /// and reseals it locally. Network failures keep the current state.
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
                // Offline: keep the sealed state; the guard's grace cutoff applies.
                result.Mode = LicenseGuard.Evaluate(state, nowUtc);
                return result;
            }
            result.Contacted = true;

            var parsed = ActivationService.ParseDeviceLink(linkJson, state.LicenseKey, state.DeviceId);
            if (!parsed.Ok)
            {
                // Verified negative answer: suspended / expired / unbound.
                result.Reason = parsed.Reason;
                if (string.Equals(parsed.Reason, "SUSPENDED", StringComparison.OrdinalIgnoreCase))
                {
                    state.Status = "suspended";
                    _activation.Reseal(state);
                    result.Changed = true;
                }
                else if (string.Equals(parsed.Reason, "EXPIRED", StringComparison.OrdinalIgnoreCase))
                {
                    state.Status = "expired";
                    _activation.Reseal(state);
                    result.Changed = true;
                }
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
