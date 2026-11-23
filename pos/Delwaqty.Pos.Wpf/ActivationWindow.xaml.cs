using System;
using System.Windows;
using Delwaqty.Pos.Core.Auth;
using Delwaqty.Pos.Core.Licensing;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Wpf
{
    public partial class ActivationWindow : Window
    {
        private readonly ActivationService _activation;
        public ActivationState ActivatedState { get; private set; }

        public ActivationWindow(ActivationService activation)
        {
            InitializeComponent();
            _activation = activation;
        }

        private async void Activate_Click(object sender, RoutedEventArgs e)
        {
            ErrorText.Text = "";
            var email = (EmailBox.Text ?? "").Trim();
            var password = PasswordBox.Password ?? "";
            var key = (KeyBox.Text ?? "").Trim();

            if (email.Length == 0 || password.Length == 0)
            {
                ErrorText.Text = "اكتب البريد وكلمة المرور لحساب التاجر";
                return;
            }
            LicenseInfo info;
            string keyError;
            if (!LicenseKey.TryParse(key, out info, out keyError))
            {
                ErrorText.Text = "مفتاح غير صحيح: " + keyError;
                return;
            }

            ActivateButton.IsEnabled = false;
            ActivateButton.Content = "جاري التفعيل...";
            try
            {
                var http = new System.Net.Http.HttpClient();
                var auth = new AuthClient(PosConfig.SupabaseUrl, PosConfig.SupabaseAnonKey, http);
                var sync = new SyncClient(PosConfig.SupabaseUrl, PosConfig.SupabaseAnonKey, http);
                var result = await _activation.ActivateAsync(auth, sync, email, password, key,
                    _activation.LocalDeviceId);
                if (!result.Ok)
                {
                    ErrorText.Text = ArabicReason(result.Reason, result.Error);
                    return;
                }
                ActivatedState = result.State;
                DialogResult = true;
                Close();
            }
            catch (Exception ex)
            {
                ErrorText.Text = "تعذر الاتصال بالخادم. تأكد من الإنترنت وحاول مرة أخرى.";
                System.Diagnostics.Debug.WriteLine(ex.Message);
            }
            finally
            {
                ActivateButton.IsEnabled = true;
                ActivateButton.Content = "تفعيل";
            }
        }

        internal static string ArabicReason(string reason, string detail)
        {
            switch (reason)
            {
                case "AUTH_FAILED": return "بيانات الدخول غير صحيحة. تأكد من البريد وكلمة المرور.";
                case "UNKNOWN_KEY": return "مفتاح غير معروف. تأكد من نسخه كاملاً.";
                case "NOT_AUTHORIZED": return "هذا المفتاح لا يخص حسابك. تواصل مع الدعم.";
                case "SUSPENDED": return "الترخيص موقوف من المنصة. تواصل مع الدعم.";
                case "BOUND_TO_OTHER_DEVICE": return "المفتاح مفعّل على جهاز آخر. تواصل مع الدعم لنقله.";
                case "EXPIRED": return "الترخيص منتهي. جدد الاشتراك من المنصة.";
                case "OTHER_MERCHANT_DATA_PENDING":
                    return "هناك بيانات غير مرفوعة لتاجر آخر على هذا الجهاز. فعّل التاجر السابق وارفع بياناته أولاً.";
                case "NETWORK": return "تعذر الاتصال بالخادم. تأكد من الإنترنت وحاول مرة أخرى.";
                default: return "تعذر التفعيل (" + reason + ")" + (detail != null ? ": " + detail : "");
            }
        }
    }
}
