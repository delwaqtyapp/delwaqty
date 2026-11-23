using System;
using System.Windows;
using System.Windows.Controls;

namespace Delwaqty.Pos.Wpf
{
    public partial class ReceiptWindow : Window
    {
        private readonly string _receipt;
        private readonly string _customerPhone;

        public ReceiptWindow(string receiptText, string customerPhone)
        {
            InitializeComponent();
            _receipt = receiptText;
            _customerPhone = customerPhone;
            ReceiptText.Text = receiptText;
        }

        private void Print_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var dlg = new PrintDialog();
                if (dlg.ShowDialog() != true) return;
                var visual = new TextBlock
                {
                    Text = _receipt,
                    FontFamily = new System.Windows.Media.FontFamily("Courier New"),
                    FontSize = 13,
                    Margin = new Thickness(8),
                };
                visual.Measure(new System.Windows.Size(dlg.PrintableAreaWidth, double.PositiveInfinity));
                visual.Arrange(new Rect(visual.DesiredSize));
                dlg.PrintVisual(visual, "Delwaqty POS receipt");
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, "تعذرت الطباعة: " + ex.Message, "الإيصال",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private void WhatsApp_Click(object sender, RoutedEventArgs e)
        {
            // wa.me deep link: free, no API. Phone optional; without it the
            // cashier picks the contact in WhatsApp.
            var phone = (_customerPhone ?? "").Trim().TrimStart('+').Replace(" ", "");
            if (phone.StartsWith("01") && phone.Length == 11) phone = "2" + phone; // Egypt
            var url = "https://wa.me/" + phone + "?text=" + Uri.EscapeDataString(_receipt);
            try
            {
                System.Diagnostics.Process.Start(
                    new System.Diagnostics.ProcessStartInfo(url) { UseShellExecute = true });
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, "تعذر فتح واتساب: " + ex.Message, "الإيصال",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private void Close_Click(object sender, RoutedEventArgs e) { Close(); }
    }
}
