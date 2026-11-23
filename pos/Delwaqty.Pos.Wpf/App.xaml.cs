using System;
using System.Net.Http;
using System.Windows;
using Delwaqty.Pos.Core.Auth;
using Delwaqty.Pos.Core.Licensing;
using Delwaqty.Pos.Core.Protection;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Wpf
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            var rootDir = AppPaths.DataDir();
            DataDirSecurity.Harden(rootDir); // #114: tighten the shared dir ACL (Windows)
            var activation = new ActivationService(rootDir, PosConfig.BuildFlavor);
            var state = activation.Restore();

            if (state != null && LicenseGuard.Evaluate(state, DateTimeOffset.UtcNow) == PosMode.Locked)
            {
                // #119: past the offline cutoff (or suspended from a previous
                // refresh): try one verified online refresh before asking for
                // re-activation. Local data is never touched either way.
                TryOnlineRefresh(activation, state);
                if (LicenseGuard.Evaluate(state, DateTimeOffset.UtcNow) == PosMode.Locked)
                    state = null; // forces the activation window below
            }

            if (state == null)
            {
                var win = new ActivationWindow(activation);
                if (win.ShowDialog() != true)
                {
                    Shutdown();
                    return;
                }
                state = win.ActivatedState;
            }

            var main = new MainWindow(activation, state);
            MainWindow = main;
            main.Show();
        }

        /// <summary>Best-effort one-shot refresh at startup; silent on any failure.</summary>
        private static void TryOnlineRefresh(ActivationService activation, ActivationState state)
        {
            try
            {
                string refresh, email;
                if (!activation.TryLoadRefreshToken(out refresh, out email)) return;
                var http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
                var auth = new AuthClient(PosConfig.SupabaseUrl, PosConfig.SupabaseAnonKey, http);
                var sync = new SyncClient(PosConfig.SupabaseUrl, PosConfig.SupabaseAnonKey, http);
                var session = auth.Refresh(refresh).GetAwaiter().GetResult();
                activation.SaveRefreshToken(session.RefreshToken, session.Email ?? email);
                sync.AccessToken = session.AccessToken;
                state.ValidatedAtUtc = DateTimeOffset.MinValue; // force the refresh
                new LicenseRefresher(activation, sync)
                    .RefreshAsync(state, DateTimeOffset.UtcNow).GetAwaiter().GetResult();
            }
            catch { /* offline or expired session: the guard's cutoff applies */ }
        }
    }
}
