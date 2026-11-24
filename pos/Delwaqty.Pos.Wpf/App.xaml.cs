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
#if SCREENSHOT_TOUR
            // CI screenshot instrumentation - compiled ONLY into the dedicated
            // tour build (pos-windows.yml passes -p:DefineConstants). The shipped
            // cashier ZIP contains none of this: activation cannot be skipped at
            // runtime. The tour synthesizes an active state and opens the main
            // window straight away so the runner can capture every tab.
            if (Environment.GetEnvironmentVariable("DELWAQTY_SCREENSHOT_TOUR") == "1")
            {
                var tourState = new ActivationState
                {
                    LicenseKey = "SCREENSHOT-TOUR",
                    Plan = "pro",
                    Pro = true,
                    Status = "active",
                    ExpiresAt = DateTimeOffset.UtcNow.AddDays(30),
                    MerchantId = "screenshot-tour",
                    MerchantName = "متجر تجريبي",
                    MerchantType = "grocery",
                    MerchantPhone = "01000000000",
                    MerchantAddress = "شارع التجربة ١",
                    DeviceId = "screenshot-device",
                    ValidatedAtUtc = DateTimeOffset.UtcNow,
                    Flavor = PosConfig.BuildFlavor,
                };
                var tourWin = new MainWindow(activation, tourState);
                MainWindow = tourWin;
                tourWin.Show();
                return;
            }
#endif
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

            // Upgrade completeness: unverifiable legacy flat-layout data with
            // an unsynced queue must not vanish under a fresh scope. Enter
            // the visible repair state: no selling, no files touched, until
            // support runs a verified migration.
            var repair = activation.LegacyRepairReason(state.MerchantId);
            if (repair != null)
            {
                MessageBox.Show(
                    "توجد بيانات قديمة غير متزامنة على هذا الجهاز لا يمكن التحقق من التاجر المالك لها.\n" +
                    "تواصل مع الدعم لترحيلها قبل التشغيل — بياناتك محفوظة كما هي ولم يُمسّ أي ملف.\n\n(" + repair + ")",
                    "إصلاح البيانات", MessageBoxButton.OK, MessageBoxImage.Warning);
                Shutdown();
                return;
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
