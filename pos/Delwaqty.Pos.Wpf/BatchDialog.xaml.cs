using System;
using System.Globalization;
using System.Windows;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>Record a restock batch (توريد) with its expiry date.</summary>
    public partial class BatchDialog : Window
    {
        public decimal Qty { get; private set; }
        public DateTime Expiry { get; private set; }
        public string BatchNo { get; private set; }

        public BatchDialog(string itemName)
        {
            InitializeComponent();
            ItemText.Text = "الصنف: " + itemName;
        }

        private void Save_Click(object sender, RoutedEventArgs e)
        {
            decimal qty;
            if (!decimal.TryParse(QtyBox.Text, out qty) || qty <= 0)
            {
                MessageBox.Show(this, "أدخل كمية صحيحة", "توريد", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            DateTime expiry;
            var text = (ExpiryBox.Text ?? "").Trim();
            // Accept yyyy-MM or yyyy-MM-dd.
            if (text.Length == 7) text += "-01";
            if (!DateTime.TryParseExact(text, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out expiry))
            {
                MessageBox.Show(this, "أدخل التاريخ بصيغة سنة-شهر مثل 2027-05", "توريد",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            Qty = qty;
            Expiry = expiry;
            BatchNo = string.IsNullOrWhiteSpace(BatchNoBox.Text) ? null : BatchNoBox.Text.Trim();
            DialogResult = true;
            Close();
        }

        private void Cancel_Click(object sender, RoutedEventArgs e) { DialogResult = false; Close(); }
    }
}
