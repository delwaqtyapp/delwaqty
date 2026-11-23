using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>
    /// Split-payment entry. Cash/InstaPay/Vodafone Cash/card cover the total;
    /// the آجل remainder requires a customer (debt ledger). Confirm closes the
    /// SaleBuilder (it auto-balances any remainder to cash, or to deferred
    /// when a customer is set).
    /// </summary>
    public partial class PaymentDialog : Window
    {
        private readonly SaleBuilder _sale;
        private readonly Func<IEnumerable<PullApplier.PosCustomer>> _customers;

        public PaymentDialog(SaleBuilder sale, Func<IEnumerable<PullApplier.PosCustomer>> customers)
        {
            InitializeComponent();
            _sale = sale;
            _customers = customers;
            Refresh();
        }

        private void Refresh()
        {
            TotalText.Text = _sale.Total.ToString("0.##");
            PaidText.Text = _sale.PaidAmount.ToString("0.##");
            RemainText.Text = _sale.DeferredAmount.ToString("0.##");
            var labels = _sale.Payments
                .Select(p => ReceiptBuilder.MethodLabel(p.Method) + "  " + p.Amount.ToString("0.##"))
                .ToList();
            PaymentsList.ItemsSource = labels;
            if (!string.IsNullOrEmpty(_sale.CustomerName))
                Title = "الدفع - العميل: " + _sale.CustomerName;
        }

        private void AddAmount(string method)
        {
            var remainder = _sale.Total - _sale.Payments.Sum(p => p.Amount);
            if (remainder <= 0) return;
            var amount = InputDialog.AskAmount(this, ReceiptBuilder.MethodLabel(method),
                "المبلغ (" + ReceiptBuilder.MethodLabel(method) + "):", remainder.ToString("0.##"));
            if (!amount.HasValue || amount.Value <= 0) return;
            try { _sale.AddPayment(method, amount.Value); }
            catch (ArgumentException ex)
            {
                MessageBox.Show(this, ex.Message, "الدفع", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
            Refresh();
        }

        private void AddCash(object s, RoutedEventArgs e) { AddAmount("cash"); }
        private void AddInstaPay(object s, RoutedEventArgs e) { AddAmount("instapay"); }
        private void AddVodafone(object s, RoutedEventArgs e) { AddAmount("vodafone_cash"); }
        private void AddCard(object s, RoutedEventArgs e) { AddAmount("card"); }

        private void AddDeferred(object s, RoutedEventArgs e)
        {
            if (string.IsNullOrEmpty(_sale.CustomerId) && string.IsNullOrEmpty(_sale.CustomerName))
            {
                var dlg = new CustomerDialog(_customers()) { Owner = this };
                if (dlg.ShowDialog() != true) return;
                if (dlg.Selected != null)
                {
                    _sale.CustomerId = dlg.Selected.Id;
                    _sale.CustomerName = dlg.Selected.Name;
                }
                else
                {
                    // New customer created in the dialog: the caller enqueues the
                    // customer op; the sale references them by name until sync.
                    _sale.CustomerName = dlg.NewCustomerName;
                    NewCustomer = dlg;
                }
            }
            AddAmount("deferred");
        }

        /// <summary>Non-null when the payer is a new customer that must be enqueued.</summary>
        public CustomerDialog NewCustomer { get; private set; }

        private void RemovePayment(object s, RoutedEventArgs e)
        {
            var idx = PaymentsList.SelectedIndex;
            if (idx < 0 || idx >= _sale.Payments.Count) return;
            _sale.RemovePaymentAt(idx);
            Refresh();
        }

        private void Confirm_Click(object sender, RoutedEventArgs e)
        {
            try { _sale.Close(); }
            catch (InvalidOperationException ex)
            {
                MessageBox.Show(this, "لا يمكن إتمام البيع: " + ex.Message, "الدفع",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            DialogResult = true;
            Close();
        }

        private void Cancel_Click(object sender, RoutedEventArgs e) { DialogResult = false; Close(); }
    }
}
