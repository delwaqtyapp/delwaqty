using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using Delwaqty.Pos.Core.Ota;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>
    /// OTA update dialog for the cashier: shows the offered version and
    /// notes, downloads the signed-release installer with progress (SHA-256
    /// verified in Core - a missing or wrong digest refuses the install),
    /// then hands off to the Inno setup with /VERYSILENT /NORESTART (the
    /// path pos/installer/delwaqty.iss documents) and exits so the
    /// installer can replace the running app.
    /// </summary>
    public partial class UpdateDialog : Window
    {
        private readonly OtaUpdateService _ota;
        private OtaCheckResult _offered;
        private string _downloadedFile;

        public UpdateDialog(OtaUpdateService ota)
        {
            InitializeComponent();
            _ota = ota;
            Loaded += async (s, e) => await CheckAsync();
        }

        private void SetState(string header, string notes, string primary, bool primaryEnabled)
        {
            HeaderText.Text = header;
            NotesText.Text = notes ?? "";
            PrimaryButton.Content = primary;
            PrimaryButton.IsEnabled = primaryEnabled;
        }

        private async Task CheckAsync()
        {
            SetState("جارٍ البحث عن تحديث…", "", "تحقق", false);
            DownloadProgress.Visibility = Visibility.Collapsed;
            ProgressText.Visibility = Visibility.Collapsed;
            OtaCheckResult result;
            try
            {
                result = await _ota.CheckForUpdateAsync(PosConfig.OtaBuildNumber);
            }
            catch
            {
                result = null;
            }
            if (result == null)
            {
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
            if (_downloadedFile != null)
            {
                Install();
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
            var result = await _ota.DownloadLatestAsync(_offered, dir, progress);
            DownloadProgress.Visibility = Visibility.Collapsed;
            ProgressText.Visibility = Visibility.Collapsed;

            if (!result.Ok)
            {
                if (result.Error == "missing_checksum" || result.Error == "checksum_mismatch")
                {
                    // Never offer to install an unverified artifact.
                    SetState("فشل التحقق من سلامة التحديث", "تعذر التأكد من سلامة ملف التحديث، لذلك تم إلغاء التثبيت حمايةً للجهاز.", "إغلاق", true);
                }
                else
                {
                    SetState("فشل تنزيل التحديث", "تحقق من اتصال الإنترنت وحاول مرة أخرى.", "إعادة المحاولة", true);
                }
                return;
            }

            _downloadedFile = result.File;
            SetState("التحديث جاهز للتثبيت", "سيتم إغلاق التطبيق وتثبيت التحديث الآن. قد يطلب Windows إذن المسؤول.", "تثبيت وإعادة التشغيل", true);
        }

        private void Install()
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = _downloadedFile,
                    Arguments = "/VERYSILENT /NORESTART",
                    UseShellExecute = true,
                    Verb = "runas", // the installer needs admin (PrivilegesRequired=admin)
                });
            }
            catch
            {
                SetState("تعذر بدء التثبيت", "لم يبدأ المثبّت — ربما رُفض إذن المسؤول.", "إغلاق", true);
                _downloadedFile = null;
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
