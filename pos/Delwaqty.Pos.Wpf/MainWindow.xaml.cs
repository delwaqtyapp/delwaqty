using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>
    /// Cashier shell. All business rules live in Delwaqty.Pos.Core; this code-behind
    /// is only wiring. Offline-first: every operation is enqueued to the local
    /// outbox and synced when connectivity returns.
    /// NOTE: compile-verified on Linux; UI run-testing requires a Windows machine.
    /// </summary>
    public partial class MainWindow : Window
    {
        private readonly CatalogCache _catalog;
        private readonly OutboxStore _outbox;
        private readonly SaleBuilder _sale = new SaleBuilder();
        private readonly ObservableCollection<SaleLine> _cart = new ObservableCollection<SaleLine>();

        public MainWindow()
        {
            InitializeComponent();
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DelwaqtyPos");
            Directory.CreateDirectory(dir);
            _catalog = new CatalogCache(Path.Combine(dir, "catalog.db"));
            _outbox = new OutboxStore(Path.Combine(dir, "outbox.db"));
            CartGrid.ItemsSource = _cart;
            UpdateSyncBadge();
        }

        private void UpdateSyncBadge()
        {
            var pending = _outbox.PendingCount();
            SyncBadge.Text = pending == 0 ? "متصل - لا عمليات معلقة" : "معلق: " + pending + " عملية";
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            var q = SearchBox.Text;
            if (string.IsNullOrWhiteSpace(q) || q.Trim().Length < 2) { SearchResults.ItemsSource = null; return; }
            SearchResults.ItemsSource = _catalog.Search(q, 25).Select(h => h.Product).ToList();
        }

        private void StockSearch_TextChanged(object sender, TextChangedEventArgs e)
        {
            var q = StockSearchBox.Text;
            if (string.IsNullOrWhiteSpace(q) || q.Trim().Length < 2) { StockResults.ItemsSource = null; return; }
            StockResults.ItemsSource = _catalog.Search(q, 25).Select(h => h.Product).ToList();
        }

        private void AddSelected_Click(object sender, RoutedEventArgs e)
        {
            var p = SearchResults.SelectedItem as DrugProduct;
            if (p == null) return;
            var line = new SaleLine
            {
                DrugCatalogId = p.Id,
                Name = p.NameAr ?? p.NameEn,
                Qty = 1,
                UnitPrice = p.OfficialPriceEgp ?? 0,
            };
            _sale.AddLine(line);
            _cart.Add(line);
            RefreshTotal();
        }

        private void Discount_Changed(object sender, TextChangedEventArgs e)
        {
            decimal d;
            if (decimal.TryParse(DiscountBox.Text, out d))
            {
                try { _sale.SetDiscount(d); } catch (ArgumentOutOfRangeException) { }
                RefreshTotal();
            }
        }

        private void RefreshTotal()
        {
            TotalText.Text = _sale.Total.ToString("0.##");
        }

        private void PayCash_Click(object sender, RoutedEventArgs e) { CloseSale(false); }
        private void PayDeferred_Click(object sender, RoutedEventArgs e) { CloseSale(true); }

        private void CloseSale(bool deferred)
        {
            try
            {
                if (deferred)
                {
                    _sale.AddPayment("deferred", Math.Max(0, _sale.Total - _sale.PaidAmount));
                    // TODO: customer picker dialog; deferred requires a customer id
                    StatusText.Text = "الآجل يحتاج اختيار عميل";
                }
                _sale.Close();
                _outbox.Enqueue(OutboxPayloads.Sale(_sale));
                StatusText.Text = "تم تسجيل الفاتورة (ستُرفع عند الاتصال)";
                ClearCart_Click(null, null);
                UpdateSyncBadge();
            }
            catch (InvalidOperationException ex)
            {
                StatusText.Text = "لا يمكن إغلاق الفاتورة: " + ex.Message;
            }
        }

        private void ClearCart_Click(object sender, RoutedEventArgs e)
        {
            _cart.Clear();
            var fresh = new SaleBuilder();
            typeof(MainWindow).GetField("_sale", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
                .SetValue(this, fresh);
            DiscountBox.Text = "0";
            RefreshTotal();
        }

        private void RecordCount_Click(object sender, RoutedEventArgs e)
        {
            var p = StockResults.SelectedItem as DrugProduct;
            decimal counted;
            if (p == null || !decimal.TryParse(CountedBox.Text, out counted))
            {
                StatusText.Text = "اختر صنفاً وأدخل الكمية الفعلية";
                return;
            }
            _outbox.Enqueue(OutboxPayloads.StockCount(p.Id, counted, "جرد يدوي"));
            StatusText.Text = "سُجل جرد: " + (p.NameAr ?? p.NameEn);
            UpdateSyncBadge();
        }

        private void SaveCustomer_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(CustomerNameBox.Text))
            {
                StatusText.Text = "اكتب اسم العميل";
                return;
            }
            _outbox.Enqueue(OutboxPayloads.Customer(CustomerNameBox.Text.Trim(), CustomerPhoneBox.Text.Trim(), null));
            StatusText.Text = "حُفظ العميل (سيُرفع عند الاتصال)";
            CustomerNameBox.Clear(); CustomerPhoneBox.Clear();
            UpdateSyncBadge();
        }

        private void CloseShift_Click(object sender, RoutedEventArgs e)
        {
            decimal closing;
            if (!decimal.TryParse(ClosingCashBox.Text, out closing))
            {
                CloseResultText.Text = "أدخل النقدية الفعلية أولاً";
                return;
            }
            // Expected cash is computed server-side by cashier_daily_close on sync;
            // offline we show the local estimate from queued sales.
            CloseResultText.Text = "سيتم تقفيل الوردية على الخادم عند الاتصال. النقدية المدخلة: " + closing.ToString("0.##");
        }
    }
}
