using System;
using System.Windows;
using System.Windows.Controls;
using Delwaqty.Pos.Core.Auth;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>
    /// Re-sign-in after the saved session was lost (expired or revoked). Reuses
    /// the activation fields (merchant email + password) but NOT the license
    /// key: the device stays activated, only the session is renewed. The
    /// server still decides what this account may do.
    /// </summary>
    public sealed class SignInAgainDialog : Window
    {
        private readonly TextBox _email = new TextBox { Padding = new Thickness(8), FlowDirection = FlowDirection.LeftToRight };
        private readonly PasswordBox _password = new PasswordBox { Padding = new Thickness(8) };
        private readonly TextBlock _error = new TextBlock { Foreground = System.Windows.Media.Brushes.Firebrick, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 8, 0, 0) };
        private readonly Button _go = new Button { Content = "تسجيل الدخول", Padding = new Thickness(16, 8, 16, 8), Margin = new Thickness(0, 12, 0, 0) };
        private readonly AuthClient _auth;
        private readonly string _knownEmail;

        public AuthSession Session { get; private set; }

        public SignInAgainDialog(AuthClient auth, string knownEmail)
        {
            _auth = auth;
            Title = "دلوقتي كاشير - تسجيل الدخول من جديد";
            Width = 460; SizeToContent = SizeToContent.Height;
            FlowDirection = FlowDirection.RightToLeft;
            WindowStartupLocation = WindowStartupLocation.CenterOwner;
            ResizeMode = ResizeMode.NoResize; FontSize = 16;
            _email.Text = knownEmail ?? "";
            _knownEmail = string.IsNullOrWhiteSpace(knownEmail) ? null : knownEmail.Trim();
            // The saved account is fixed: this dialog only renews ITS session.
            _email.IsReadOnly = _knownEmail != null;
            var panel = new StackPanel { Margin = new Thickness(24) };
            panel.Children.Add(new TextBlock { Text = "انتهت الجلسة. سجّل الدخول لرفع المبيعات المعلقة. البيع يستمر بدون اتصال.", TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 12) });
            panel.Children.Add(new TextBlock { Text = "حساب التاجر (البريد):" });
            panel.Children.Add(_email);
            panel.Children.Add(new TextBlock { Text = "كلمة المرور:", Margin = new Thickness(0, 8, 0, 0) });
            panel.Children.Add(_password);
            panel.Children.Add(_go);
            panel.Children.Add(_error);
            Content = panel;
            _go.Click += Go_Click;
        }

        private async void Go_Click(object sender, RoutedEventArgs e)
        {
            _error.Text = "";
            var email = (_email.Text ?? "").Trim();
            if (email.Length == 0 || _password.Password.Length == 0)
            {
                _error.Text = "اكتب البريد وكلمة المرور";
                return;
            }
            _go.IsEnabled = false;
            try
            {
                var session = await _auth.SignInPassword(_knownEmail ?? email, _password.Password);
                if (_knownEmail != null && session.Email != null &&
                    !string.Equals(session.Email, _knownEmail, StringComparison.OrdinalIgnoreCase))
                {
                    _error.Text = "هذا الحساب مختلف عن حساب التاجر المفعّل على الجهاز.";
                    return;
                }
                Session = session;
                DialogResult = true;
                Close();
            }
            catch (Exception ex)
            {
                var offline = ex is System.Net.Http.HttpRequestException || ex is OperationCanceledException;
                _error.Text = offline
                    ? "تعذر الاتصال بالخادم. تأكد من الإنترنت وحاول مرة أخرى."
                    : "بيانات الدخول غير صحيحة. تأكد من البريد وكلمة المرور.";
            }
            finally { _go.IsEnabled = true; }
        }
    }
}
