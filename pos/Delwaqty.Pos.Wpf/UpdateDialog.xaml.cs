using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using Delwaqty.Pos.Core.Ota;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>
    /// OTA update dialog for the cashier: shows the offered version and
    /// notes, downloads the hash-verified installer with progress (SHA-256
    /// verified in Core against the manifest digest - the Inno installer is
    /// NOT digitally signed, so a missing or wrong digest refuses the
    /// install), then re-verifies the file one more time immediately before
    /// handing off to the Inno setup with /VERYSILENT /NORESTART (the path
    /// pos/installer/delwaqty.iss documents) and exits so the installer can
    /// replace the running app.
    /// </summary>
    public partial class UpdateDialog : Window
    {
        private readonly OtaUpdateService _ota;
        private readonly CancellationTokenSource _closing = new CancellationTokenSource();
        private OtaCheckResult _offered;
        private OtaVerifiedInstaller _installer;
        private bool _primaryCloses;

        public UpdateDialog(OtaUpdateService ota)
        {
            InitializeComponent();
            _ota = ota;
            Loaded += async (s, e) => await CheckAsync();
            Closed += (s, e) => _closing.Cancel();
        }

        private void SetState(string header, string notes, string primary, bool primaryEnabled,
            bool primaryCloses = false)
        {
            HeaderText.Text = header;
            NotesText.Text = notes ?? "";
            PrimaryButton.Content = primary;
            PrimaryButton.IsEnabled = primaryEnabled;
            _primaryCloses = primaryCloses;
        }

        private async Task CheckAsync()
        {
            SetState("جارٍ البحث عن تحديث…", "", "تحقق", false);
            DownloadProgress.Visibility = Visibility.Collapsed;
            ProgressText.Visibility = Visibility.Collapsed;
            OtaCheckResult result;
            try
            {
                result = await _ota.CheckForUpdateAsync(PosConfig.OtaBuildNumber, _closing.Token);
            }
            catch
            {
                result = null;
            }
            if (result == null || result.Error != null)
            {
                // A failed check is UNAVAILABLE, never "up to date".
                SetState("تعذر التحقق من التحديثات", "تحقق من اتصال الإنترنت وحاول مرة أخرى.", "إعادة المحاولة", true);
                return;
            }
            if (!result.NeedsUpdate)
            {
                SetState("التطبيق محدث", "لا يوجد تحديث جديد — أنت على أحدث نسخة.", "إعادة التحقق", true);
                _offered = null;
                return;
            }
            _offered = result;
            SetState(
                "يوجد تحديث جديد (الإصدار " + result.Channel.VersionName + ")",
                result.Channel.Notes,
                "تنزيل التحديث",
                true);
        }

        private async void Primary_Click(object sender, RoutedEventArgs e)
        {
            if (_primaryCloses)
            {
                Close();
                return;
            }
            if (_installer != null)
            {
                await InstallAsync();
                return;
            }
            if (_offered == null)
            {
                await CheckAsync();
                return;
            }
            await DownloadAsync();
        }

        private async Task DownloadAsync()
        {
            SetState("جارٍ تنزيل التحديث…", _offered.Channel.Notes, "تنزيل…", false);
            DownloadProgress.Visibility = Visibility.Visible;
            ProgressText.Visibility = Visibility.Visible;
            DownloadProgress.Value = 0;
            var progress = new Progress<double>(f =>
            {
                DownloadProgress.Value = f * 100;
                ProgressText.Text = ((int)(f * 100)) + "%";
            });
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "DelwaqtyPos", "updates");
            var result = await _ota.DownloadLatestAsync(_offered, dir, progress, _closing.Token);
            DownloadProgress.Visibility = Visibility.Collapsed;
            ProgressText.Visibility = Visibility.Collapsed;

            if (!result.Ok)
            {
                if (result.Error == "missing_checksum" || result.Error == "checksum_mismatch" ||
                    result.Error == "invalid_asset" || result.Error == "too_large")
                {
                    // Never offer to install or retry an unverified artifact.
                    SetState("فشل التحقق من سلامة التحديث",
                        "تعذر التأكد من سلامة ملف التحديث، لذلك تم إلغاء التثبيت حمايةً للجهاز.",
                        "إغلاق", true, primaryCloses: true);
                }
                else if (result.Error == "cancelled")
                {
                    SetState("أُلغي التنزيل", "", "إغلاق", true, primaryCloses: true);
                }
                else
                {
                    SetState("فشل تنزيل التحديث", "تحقق من اتصال الإنترنت وحاول مرة أخرى.", "إعادة المحاولة", true);
                }
                return;
            }

            _installer = result.Installer;
            // /NORESTART: the silent install does NOT relaunch the app, and
            // the copy must not promise one.
            SetState("التحديث جاهز للتثبيت",
                "سيُغلق التطبيق ويُثبَّت التحديث بصمت دون إعادة تشغيل تلقائية — شغّل التطبيق من جديد بعد انتهاء التثبيت. قد يطلب Windows إذن المسؤول.",
                "تثبيت", true);
        }

        private async Task InstallAsync()
        {
            // Re-verify the exact bytes that passed the digest check right
            // before launch: a swapped file must never be executed.
            if (!_installer.Reverify())
            {
                _installer = null;
                SetState("فشل التحقق من سلامة التحديث",
                    "تغيّر ملف التحديث بعد تنزيله، لذلك أُلغي التثبيت حمايةً للجهاز.",
                    "إغلاق", true, primaryCloses: true);
                return;
            }
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = _installer.File,
                    Arguments = "/VERYSILENT /NORESTART",
                    UseShellExecute = true,
                    Verb = "runas", // the installer needs admin (PrivilegesRequired=admin)
                });
            }
            catch
            {
                SetState("تعذر بدء التثبيت", "لم يبدأ المثبّت — ربما رُفض إذن المسؤول.", "إغلاق", true,
                    primaryCloses: true);
                _installer = null;
                return;
            }
            Application.Current.Shutdown();
        }

        private void Close_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }
    }
}
