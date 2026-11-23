using System;
using System.Windows;
using Delwaqty.Pos.Core.Licensing;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Wpf
{
    public partial class App : Application
    {
        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);
            var dataDir = AppPaths.DataDir();
            var activation = new ActivationService(dataDir);
            var state = activation.Restore();

            if (state != null && IsPastGrace(state))
            {
                // Past grace with no server contact: re-activate, keep local data.
                state = null;
            }

            if (state == null)
            {
                var win = new ActivationWindow(activation, dataDir);
                if (win.ShowDialog() != true)
                {
                    Shutdown();
                    return;
                }
                state = win.ActivatedState;
            }

            var main = new MainWindow(activation, dataDir, state);
            MainWindow = main;
            main.Show();
        }

        /// <summary>Offline grace: the seal alone is enough until grace_until passes.</summary>
        internal static bool IsPastGrace(ActivationState state)
        {
            if (!state.ExpiresAt.HasValue) return false; // lifetime
            var graceEnd = state.GraceUntil ?? state.ExpiresAt.Value.AddDays(3);
            return DateTimeOffset.UtcNow > graceEnd && state.ValidatedAtUtc < graceEnd;
        }
    }
}
