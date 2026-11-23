using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using Delwaqty.Pos.Core.Auth;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Close;
using Delwaqty.Pos.Core.Licensing;
using Delwaqty.Pos.Core.Network;
using Delwaqty.Pos.Core.Pharmacy;
using Delwaqty.Pos.Core.Pro;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>
    /// Cashier main window. All business rules live in Delwaqty.Pos.Core;
    /// this code-behind is wiring. Offline-first: every operation is enqueued
    /// to the local outbox and synced when connectivity returns.
    /// NOTE: compile-verified on Linux; UI run-testing requires Windows
    /// (pos/docs/windows-run-test-checklist.md).
    /// </summary>
    public partial class MainWindow : Window
    {
        /// <summary>One search hit, wrapping either a store product or a catalog drug.</summary>
        public sealed class SearchRow
        {
            public string ProductId;        // store product id (null = catalog-only)
            public string DrugCatalogId;
            public string DisplayName { get; set; }
            public string DisplayPrice { get; set; }
            public string DisplayStock { get; set; }
            public string Barcode { get; set; }
            public decimal Price;
            public string Ingredient;       // pharmacy: for the controlled check
        }

        private readonly ActivationService _activation;
        private readonly ActivationState _state;
        private readonly string _dataDir;
        private readonly bool _isPharmacy;

        private readonly HttpClientFactory _http = new HttpClientFactory();
        private readonly SyncClient _sync;
        private readonly AuthClient _auth;
        private AuthSession _session;

        private readonly CatalogCache _drugs;            // pharmacy
        private readonly RetailCatalogCache _products;   // store products (both flavors)
        private readonly OutboxStore _outbox;
        private readonly LocalSalesLog _salesLog;
        private readonly BatchStore _batches;            // pharmacy
        private readonly SyncEngine _engine;

        private readonly SaleBuilder _sale = new SaleBuilder();
        private readonly ObservableCollection<SaleLine> _cart = new ObservableCollection<SaleLine>();
        private List<PullApplier.PosCustomer> _customers = new List<PullApplier.PosCustomer>();
        private string _currentShiftId;   // local grouping id (op id until adopted)
        private string _serverShiftId;    // real pos_shifts id once the pull shows it
        private decimal? _pendingCloseCash; // close recorded locally, awaiting server shift id
        private decimal _currentFloat;
        private readonly DispatcherTimer _syncTimer;
        private readonly DispatcherTimer _clockTimer;
        private bool _syncing;

        public MainWindow(ActivationService activation, string dataDir, ActivationState state)
        {
            InitializeComponent();
            _activation = activation;
            _dataDir = dataDir;
            _state = state;
            _isPharmacy = state.IsPharmacy;

            _sync = new SyncClient(PosConfig.SupabaseUrl, PosConfig.SupabaseAnonKey, _http.Client);
            _auth = new AuthClient(PosConfig.SupabaseUrl, PosConfig.SupabaseAnonKey, _http.Client);
            _drugs = new CatalogCache(Path.Combine(dataDir, "catalog.db"));
            _products = new RetailCatalogCache(Path.Combine(dataDir, "products.db"));
            _outbox = new OutboxStore(Path.Combine(dataDir, "outbox.db"));
            _salesLog = new LocalSalesLog(Path.Combine(dataDir, "sales.db"));
            _batches = new BatchStore(Path.Combine(dataDir, "batches.db"));
            _engine = new SyncEngine(_outbox, _sync, state.MerchantId);

            ConfigureFlavor();
            CartGrid.ItemsSource = _cart;
            LoadShiftState();
            RefreshShiftSales();
            UpdateSyncBadge();
            UpdateLicenseBadge();
            DeviceText.Text = "الجهاز: " + state.DeviceId + "  |  الإصدار " + PosConfig.AppVersion +
                "  |  نسخة " + PosConfig.BuildFlavor;

            _syncTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(PosConfig.SyncIntervalSeconds) };
            _syncTimer.Tick += async (s, e) => await SyncNow();
            _syncTimer.Start();
            _clockTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(30) };
            _clockTimer.Tick += (s, e) => ClockText.Text = DateTime.Now.ToString("yyyy/MM/dd HH:mm");
            _clockTimer.Start();
            Loaded += async (s, e) => await SyncNow();
            Closed += (s, e) => { _syncTimer.Stop(); _clockTimer.Stop(); };
        }

        private void ConfigureFlavor()
        {
            TitleText.Text = _isPharmacy ? "دلوقتي - كاشير الصيدلية" : "دلوقتي - كاشير المحل";
            StoreText.Text = _state.MerchantName ?? "";
            SearchHint.Text = _isPharmacy
                ? "ابحث بالاسم أو الباركود أو المادة الفعالة — Enter يضيف أول نتيجة"
                : "ابحث بالاسم أو الباركود — Enter يضيف أول نتيجة";
            BatchButton.Visibility = _isPharmacy ? Visibility.Visible : Visibility.Collapsed;
            ExpiryHeader.Visibility = _isPharmacy ? Visibility.Visible : Visibility.Collapsed;
            ExpiryGrid.Visibility = _isPharmacy ? Visibility.Visible : Visibility.Collapsed;
            AddProductButton.Visibility = _isPharmacy ? Visibility.Collapsed : Visibility.Visible;
            NetworkButton.Visibility = _isPharmacy ? Visibility.Visible : Visibility.Collapsed;
            ProButton.Visibility = _isPharmacy && _state.Pro ? Visibility.Visible : Visibility.Collapsed;
            CatalogButton.Visibility = _isPharmacy ? Visibility.Visible : Visibility.Collapsed;
            if (_isPharmacy) RefreshExpiryAlerts();
        }

        // ==================== SELL ====================

        private List<SearchRow> DoSearch(string q)
        {
            var rows = new List<SearchRow>();
            if (string.IsNullOrWhiteSpace(q) || q.Trim().Length < 2) return rows;
            // Store products first (stock + store price)...
            foreach (var h in _products.Search(q, 15))
            {
                rows.Add(new SearchRow
                {
                    ProductId = h.Product.Id,
                    DisplayName = h.Product.NameAr ?? h.Product.Name,
                    DisplayPrice = h.Product.Price.ToString("0.##"),
                    DisplayStock = h.Product.Stock.HasValue ? h.Product.Stock.Value.ToString("0.##") : "-",
                    Barcode = h.Product.Barcode,
                    Price = h.Product.Price,
                });
            }
            // ...then the MoH catalog in the pharmacy flavor.
            if (_isPharmacy)
            {
                var seen = new HashSet<string>(rows.Select(r => r.Barcode).Where(b => b != null));
                foreach (var h in _drugs.Search(q, 15))
                {
                    if (h.Product.Barcode != null && seen.Contains(h.Product.Barcode)) continue;
                    rows.Add(new SearchRow
                    {
                        DrugCatalogId = h.Product.Id,
                        DisplayName = (h.Product.NameAr ?? h.Product.NameEn) +
                            (h.Product.Strength != null ? " " + h.Product.Strength : ""),
                        DisplayPrice = h.Product.OfficialPriceEgp.HasValue
                            ? h.Product.OfficialPriceEgp.Value.ToString("0.##") + " (رسمي)" : "-",
                        DisplayStock = "-",
                        Barcode = h.Product.Barcode,
                        Price = h.Product.OfficialPriceEgp ?? 0,
                        Ingredient = h.Product.ActiveIngredient,
                    });
                }
            }
            return rows;
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            SearchResults.ItemsSource = DoSearch(SearchBox.Text);
        }

        private void SearchBox_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key != Key.Enter) return;
            var rows = SearchResults.ItemsSource as List<SearchRow>;
            // Barcode scanners end with Enter: an exact barcode hit wins.
            var raw = (SearchBox.Text ?? "").Trim();
            var exact = rows == null ? null : rows.FirstOrDefault(r => r.Barcode == raw);
            AddRow(exact ?? (rows == null ? null : rows.FirstOrDefault()));
            SearchBox.SelectAll();
        }

        private void AddSelected_Click(object sender, RoutedEventArgs e)
        {
            AddRow(SearchResults.SelectedItem as SearchRow);
        }

        private void AddRow(SearchRow row)
        {
            if (row == null) return;
            if (_isPharmacy && ControlledSubstances.IsControlled(row.Ingredient ?? row.DisplayName))
            {
                MessageBox.Show(this, ControlledSubstances.WarningAr, "تنبيه صرف",
                    MessageBoxButton.OK, MessageBoxImage.Exclamation);
            }
            var line = new SaleLine
            {
                ProductId = row.ProductId,
                DrugCatalogId = row.DrugCatalogId,
                Name = row.DisplayName,
                Qty = 1,
                UnitPrice = row.Price,
            };
            _sale.AddLine(line);
            _cart.Add(line);
            RefreshTotal();
        }

        private void QuickLine_Click(object sender, RoutedEventArgs e)
        {
            var name = InputDialog.Ask(this, "صنف سريع", "اسم الصنف:", "");
            if (string.IsNullOrWhiteSpace(name)) return;
            var price = InputDialog.AskAmount(this, "صنف سريع", "السعر:", "");
            if (!price.HasValue) return;
            var qty = InputDialog.AskAmount(this, "صنف سريع", "الكمية (للوزن: بالكيلو مثل 0.5):", "1");
            if (!qty.HasValue || qty.Value <= 0) return;
            var line = new SaleLine
            {
                Name = name.Trim(),
                Qty = qty.Value,
                UnitPrice = price.Value,
                IsWeightBased = qty.Value != Math.Floor(qty.Value),
            };
            _sale.AddLine(line);
            _cart.Add(line);
            RefreshTotal();
        }

        private SaleLine SelectedLine { get { return CartGrid.SelectedItem as SaleLine; } }

        private void IncQty_Click(object sender, RoutedEventArgs e) { BumpQty(1); }
        private void DecQty_Click(object sender, RoutedEventArgs e) { BumpQty(-1); }

        private void BumpQty(decimal delta)
        {
            var line = SelectedLine;
            if (line == null) return;
            if (line.Qty + delta <= 0) return;
            line.Qty += delta;
            CartGrid.Items.Refresh();
            RefreshTotal();
        }

        private void RemoveLine_Click(object sender, RoutedEventArgs e)
        {
            var idx = CartGrid.SelectedIndex;
            if (idx < 0) return;
            _sale.RemoveLineAt(idx);
            _cart.RemoveAt(idx);
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

        private void Pay_Click(object sender, RoutedEventArgs e)
        {
            if (_sale.Lines.Count == 0)
            {
                CartNote.Text = "الفاتورة فارغة";
                return;
            }
            // Only a SERVER shift id goes on the payload; a local-only shift
            // leaves shift_id null (the local journal still groups the sale).
            _sale.ShiftId = _serverShiftId;
            var dlg = new PaymentDialog(_sale, () => _customers) { Owner = this };
            if (dlg.ShowDialog() != true) return;

            // A brand-new customer from the payment dialog gets enqueued first.
            if (dlg.NewCustomer != null)
            {
                _outbox.Enqueue(OutboxPayloads.Customer(dlg.NewCustomer.NewCustomerName,
                    dlg.NewCustomer.NewCustomerPhone, null));
            }

            var op = OutboxPayloads.Sale(_sale);
            _outbox.Enqueue(op);
            _salesLog.Add(new LocalSalesLog.OutboxOpRef(op.OpId), _sale, _currentShiftId);

            if (_isPharmacy)
            {
                foreach (var line in _sale.Lines)
                {
                    var key = line.ProductId ?? line.DrugCatalogId;
                    if (key != null) _batches.Dispense(key, line.Qty);
                }
                RefreshExpiryAlerts();
            }

            var receipt = ReceiptBuilder.Build(new ReceiptBuilder.Context
            {
                StoreName = _state.MerchantName,
                StorePhone = _state.MerchantPhone,
                StoreAddress = _state.MerchantAddress,
                SaleId = op.OpId.Substring(0, 8),
                When = DateTimeOffset.Now,
                CustomerName = _sale.CustomerName,
                IsPharmacy = _isPharmacy,
            }, _sale);
            var phone = _sale.CustomerId != null
                ? (_customers.FirstOrDefault(c => c.Id == _sale.CustomerId) ?? new PullApplier.PosCustomer()).Phone
                : (dlg.NewCustomer != null ? dlg.NewCustomer.NewCustomerPhone : null);

            StatusText.Text = "تم تسجيل الفاتورة (تُرفع عند الاتصال)";
            ClearCart();
            UpdateSyncBadge();
            RefreshShiftSales();
            RefreshExpectedCash();
            new ReceiptWindow(receipt, phone) { Owner = this }.ShowDialog();
        }

        private void ClearCart_Click(object sender, RoutedEventArgs e) { ClearCart(); }

        private void ClearCart()
        {
            _cart.Clear();
            _sale.Reset();
            DiscountBox.Text = "0";
            CartNote.Text = "";
            RefreshTotal();
        }

        // ==================== STOCK ====================

        private void StockSearch_TextChanged(object sender, TextChangedEventArgs e)
        {
            StockResults.ItemsSource = DoSearch(StockSearchBox.Text);
        }

        private void RecordCount_Click(object sender, RoutedEventArgs e)
        {
            var row = StockResults.SelectedItem as SearchRow;
            decimal counted;
            if (row == null || row.ProductId == null || !decimal.TryParse(CountedBox.Text, out counted))
            {
                StatusText.Text = "اختر صنفاً مسجلاً وأدخل الكمية الفعلية";
                return;
            }
            _outbox.Enqueue(OutboxPayloads.StockCount(row.ProductId, counted, "جرد يدوي"));
            var cached = _products.ById(row.ProductId);
            if (cached != null) { cached.Stock = counted; _products.Upsert(cached); }
            StatusText.Text = "سُجل جرد: " + row.DisplayName;
            UpdateSyncBadge();
            StockResults.ItemsSource = DoSearch(StockSearchBox.Text);
        }

        private void AddBatch_Click(object sender, RoutedEventArgs e)
        {
            var row = StockResults.SelectedItem as SearchRow;
            if (row == null) { StatusText.Text = "اختر صنفاً أولاً"; return; }
            var dlg = new BatchDialog(row.DisplayName) { Owner = this };
            if (dlg.ShowDialog() != true) return;
            var key = row.ProductId ?? row.DrugCatalogId;
            _batches.AddBatch(key, row.DisplayName, dlg.Qty, dlg.Expiry, dlg.BatchNo);
            // Absolute stock correction rides the normal stock-count op when
            // the item is a tracked store product.
            if (row.ProductId != null)
            {
                var cached = _products.ById(row.ProductId);
                var newTotal = (cached != null && cached.Stock.HasValue ? cached.Stock.Value : 0) + dlg.Qty;
                _outbox.Enqueue(OutboxPayloads.StockCount(row.ProductId, newTotal, "توريد تشغيلة"));
                if (cached != null) { cached.Stock = newTotal; _products.Upsert(cached); }
            }
            StatusText.Text = "سُجل توريد: " + row.DisplayName;
            RefreshExpiryAlerts();
            UpdateSyncBadge();
        }

        private void AddProduct_Click(object sender, RoutedEventArgs e)
        {
            var creator = new ProductCreator(_sync, _state.MerchantId);
            var dlg = new AddProductDialog(creator, _products) { Owner = this };
            dlg.ShowDialog();
        }

        private void PriceChange_Click(object sender, RoutedEventArgs e)
        {
            var row = StockResults.SelectedItem as SearchRow;
            if (row == null || row.ProductId == null) { StatusText.Text = "اختر صنفاً مسجلاً أولاً"; return; }
            var price = InputDialog.AskAmount(this, "تغيير السعر", "السعر الجديد:", row.Price.ToString("0.##"));
            if (!price.HasValue) return;
            _outbox.Enqueue(OutboxPayloads.PriceChange(row.ProductId, price.Value, "manual"));
            var cached = _products.ById(row.ProductId);
            if (cached != null) { cached.Price = price.Value; _products.Upsert(cached); }
            StatusText.Text = "سُجل تغيير سعر: " + row.DisplayName;
            UpdateSyncBadge();
            StockResults.ItemsSource = DoSearch(StockSearchBox.Text);
        }

        private void BulkPrice_Click(object sender, RoutedEventArgs e)
        {
            var pct = InputDialog.AskAmount(this, "زيادة أسعار جماعية",
                "نسبة الزيادة % (مثال 10):", "");
            if (!pct.HasValue || pct.Value <= 0) return;
            if (MessageBox.Show(this, "ستُرفع أسعار كل الأصناف المتاحة بنسبة " + pct.Value + "%. متابعة؟",
                    "زيادة أسعار", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
                return;
            _outbox.Enqueue(OutboxPayloads.BulkPricePct(pct.Value));
            StatusText.Text = "سُجلت زيادة " + pct.Value + "% (تُطبق عند المزامنة)";
            UpdateSyncBadge();
        }

        private void RefreshExpiryAlerts()
        {
            if (!_isPharmacy) return;
            ExpiryGrid.ItemsSource = _batches.ExpiringSoon(
                DateTime.Today.AddDays(PosConfig.ExpiryWarnDays), 100);
        }

        // ==================== CUSTOMERS & DEBTS ====================

        private void SaveCustomer_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(CustomerNameBox.Text))
            {
                StatusText.Text = "اكتب اسم العميل";
                return;
            }
            _outbox.Enqueue(OutboxPayloads.Customer(CustomerNameBox.Text.Trim(),
                (CustomerPhoneBox.Text ?? "").Trim(), null));
            StatusText.Text = "حُفظ العميل (يُرفع عند الاتصال)";
            CustomerNameBox.Clear(); CustomerPhoneBox.Clear();
            UpdateSyncBadge();
        }

        private void DebtPayment_Click(object sender, RoutedEventArgs e)
        {
            var c = CustomersGrid.SelectedItem as PullApplier.PosCustomer;
            if (c == null) { StatusText.Text = "اختر عميلاً من القائمة"; return; }
            var amount = InputDialog.AskAmount(this, "تحصيل دفعة",
                "المبلغ المحصل من " + c.Name + " (دينه الحالي " + c.Balance.ToString("0.##") + "):", "");
            if (!amount.HasValue || amount.Value <= 0) return;
            _outbox.Enqueue(OutboxPayloads.DebtPayment(c.Id, amount.Value, null));
            StatusText.Text = "سُجلت دفعة " + amount.Value.ToString("0.##") + " من " + c.Name;
            UpdateSyncBadge();
        }

        // ==================== SHIFTS ====================

        private string ShiftPath { get { return Path.Combine(_dataDir, "shift.json"); } }

        private void LoadShiftState()
        {
            try
            {
                if (File.Exists(ShiftPath))
                {
                    var parts = File.ReadAllText(ShiftPath).Split('|');
                    if (parts.Length >= 2)
                    {
                        _currentShiftId = parts[0].Length > 0 ? parts[0] : null;
                        decimal.TryParse(parts[1], out _currentFloat);
                        if (parts.Length >= 3) _serverShiftId = parts[2].Length > 0 ? parts[2] : null;
                        if (parts.Length >= 4)
                        {
                            decimal pc;
                            if (decimal.TryParse(parts[3], out pc)) _pendingCloseCash = pc;
                        }
                    }
                }
            }
            catch { _currentShiftId = null; _serverShiftId = null; _pendingCloseCash = null; }
            RefreshShiftUi();
        }

        private void SaveShiftState()
        {
            if (_currentShiftId == null && !_pendingCloseCash.HasValue)
            {
                if (File.Exists(ShiftPath)) File.Delete(ShiftPath);
                return;
            }
            File.WriteAllText(ShiftPath,
                (_currentShiftId ?? "") + "|" + _currentFloat + "|" +
                (_serverShiftId ?? "") + "|" +
                (_pendingCloseCash.HasValue ? _pendingCloseCash.Value.ToString(System.Globalization.CultureInfo.InvariantCulture) : ""));
        }

        private void RefreshShiftUi()
        {
            ShiftStateText.Text = _currentShiftId == null
                ? "لا توجد وردية مفتوحة — افتح وردية لتجميع مبيعات اليوم"
                : "وردية مفتوحة (مرجع " + _currentShiftId.Substring(0, Math.Min(8, _currentShiftId.Length)) + ")";
            RefreshExpectedCash();
        }

        private void RefreshExpectedCash()
        {
            if (_currentShiftId == null) { ExpectedCashText.Text = "-"; return; }
            var result = DailyCloseCalculator.Compute(_currentFloat, _salesLog.CloseRecordsFor(_currentShiftId), null);
            ExpectedCashText.Text = result.ExpectedCash.ToString("0.##");
        }

        private void OpenShift_Click(object sender, RoutedEventArgs e)
        {
            if (_currentShiftId != null) { StatusText.Text = "توجد وردية مفتوحة بالفعل"; return; }
            decimal floatAmount;
            if (!decimal.TryParse(FloatBox.Text, out floatAmount) || floatAmount < 0) floatAmount = 0;
            var op = OutboxPayloads.ShiftOpen(floatAmount);
            _outbox.Enqueue(op);
            _currentShiftId = op.OpId;   // local id; the server shift id arrives on pull
            _serverShiftId = null;
            _currentFloat = floatAmount;
            SaveShiftState();
            RefreshShiftUi();
            UpdateSyncBadge();
            StatusText.Text = "فُتحت وردية بعهدة " + floatAmount.ToString("0.##");
        }

        private void CloseShift_Click(object sender, RoutedEventArgs e)
        {
            if (_currentShiftId == null) { CloseResultText.Text = "لا توجد وردية مفتوحة"; return; }
            decimal closing;
            if (!decimal.TryParse(ClosingCashBox.Text, out closing))
            {
                CloseResultText.Text = "أدخل النقدية الفعلية أولاً";
                return;
            }
            var result = DailyCloseCalculator.Compute(_currentFloat,
                _salesLog.CloseRecordsFor(_currentShiftId), closing);
            if (_serverShiftId != null)
            {
                _outbox.Enqueue(OutboxPayloads.DailyClose(_serverShiftId, closing));
            }
            else
            {
                // The shift_open op has not synced yet: record the close and let
                // the next sync enqueue it once the server shift id is known.
                _pendingCloseCash = closing;
            }
            CloseResultText.Text =
                "مبيعات: " + result.SalesTotal.ToString("0.##") + " (" + result.SaleCount + " فاتورة)\n" +
                "متوقع: " + result.ExpectedCash.ToString("0.##") + "  فعلي: " + closing.ToString("0.##") +
                "  فرق: " + (result.Difference ?? 0).ToString("0.##") + "\n" +
                "سيُقفل على الخادم عند الاتصال.";
            _currentShiftId = null;
            _serverShiftId = null;
            _currentFloat = 0;
            SaveShiftState();
            ClosingCashBox.Clear();
            RefreshShiftUi();
            RefreshShiftSales();
            UpdateSyncBadge();
        }

        public sealed class ShiftSaleRow
        {
            public string OpId;
            public string ShortId { get; set; }
            public string Total { get; set; }
            public string CustomerName { get; set; }
            public string StatusAr { get; set; }
        }

        private void RefreshShiftSales()
        {
            var rows = (_currentShiftId == null ? _salesLog.Recent(50) : _salesLog.SalesForShift(_currentShiftId))
                .Select(s => new ShiftSaleRow
                {
                    OpId = s.OpId,
                    ShortId = s.OpId.Substring(0, Math.Min(8, s.OpId.Length)),
                    Total = s.Total.ToString("0.##"),
                    CustomerName = s.CustomerName,
                    StatusAr = s.Status == "voided" ? "ملغاة" : "مكتملة",
                }).ToList();
            ShiftSalesGrid.ItemsSource = rows;
        }

        private void VoidSale_Click(object sender, RoutedEventArgs e)
        {
            var row = ShiftSalesGrid.SelectedItem as ShiftSaleRow;
            if (row == null) { StatusText.Text = "اختر فاتورة أولاً"; return; }
            if (row.StatusAr == "ملغاة") { StatusText.Text = "الفاتورة ملغاة بالفعل"; return; }
            var reason = InputDialog.Ask(this, "إلغاء فاتورة", "سبب الإلغاء:", "خطأ في الإدخال");
            if (reason == null) return;
            _outbox.Enqueue(OutboxPayloads.SaleVoid(row.OpId, reason));
            _salesLog.MarkVoided(row.OpId);
            StatusText.Text = "سُجل إلغاء الفاتورة (يُرفع عند الاتصال)";
            RefreshShiftSales();
            RefreshExpectedCash();
            UpdateSyncBadge();
        }

        // ==================== SYNC ====================

        private async System.Threading.Tasks.Task SyncNow()
        {
            if (_syncing) return;
            _syncing = true;
            try
            {
                if (!await EnsureSession()) { UpdateSyncBadge(); return; }
                var flush = await _engine.FlushAsync();
                if (flush.RepricedLines > 0 || flush.ClientPricedLines > 0)
                    StatusText.Text = "السيرفر حدّث " + flush.RepricedLines + " سعراً؛ " +
                        flush.ClientPricedLines + " صنفاً بسعرك (قيد المراجعة)";
                var pull = await _sync.Pull(_state.MerchantId, null);
                var summary = PullApplier.Apply(pull, _products);
                _customers = summary.CustomerList;
                CustomersGrid.ItemsSource = _customers;
                if (summary.OpenShiftId != null)
                {
                    if (_pendingCloseCash.HasValue)
                    {
                        // The shift was closed locally before its open synced:
                        // enqueue the close now that the server id is known.
                        _outbox.Enqueue(OutboxPayloads.DailyClose(summary.OpenShiftId, _pendingCloseCash.Value));
                        _pendingCloseCash = null;
                        SaveShiftState();
                    }
                    else if (_currentShiftId == null)
                    {
                        // A shift opened on another device: adopt it locally.
                        _currentShiftId = summary.OpenShiftId;
                        _serverShiftId = summary.OpenShiftId;
                        SaveShiftState();
                        RefreshShiftUi();
                    }
                    else if (_serverShiftId == null)
                    {
                        // Our offline-opened shift just got its server id.
                        _salesLog.RemapShift(_currentShiftId, summary.OpenShiftId);
                        _currentShiftId = summary.OpenShiftId;
                        _serverShiftId = summary.OpenShiftId;
                        SaveShiftState();
                        RefreshShiftUi();
                    }
                }
                SyncDetailText.Text = "آخر مزامنة: " + DateTime.Now.ToString("HH:mm:ss") +
                    " — أصناف: " + summary.Products + "، عملاء: " + summary.Customers +
                    (flush.Failures.Count > 0 ? "\nعمليات فشلت: " + flush.Failures.Count : "");
            }
            catch (Exception)
            {
                SyncDetailText.Text = "تعذرت المزامنة — سيُعاد تلقائياً. البيع يستمر بدون اتصال.";
            }
            finally
            {
                _syncing = false;
                UpdateSyncBadge();
            }
        }

        private async System.Threading.Tasks.Task<bool> EnsureSession()
        {
            if (_session != null && !_session.IsExpired(DateTimeOffset.UtcNow))
            {
                _sync.AccessToken = _session.AccessToken;
                return true;
            }
            string refresh, email;
            if (!_activation.TryLoadRefreshToken(out refresh, out email)) return false;
            try
            {
                _session = await _auth.Refresh(refresh);
                _activation.SaveRefreshToken(_session.RefreshToken, _session.Email ?? email);
                _sync.AccessToken = _session.AccessToken;
                return true;
            }
            catch
            {
                _session = null;
                StatusText.Text = "انتهت الجلسة — البيع يستمر، والرفع ينتظر تسجيل الدخول مرة أخرى";
                return false;
            }
        }

        private void UpdateSyncBadge()
        {
            var pending = _outbox.PendingCount();
            SyncBadge.Text = pending == 0 ? "لا عمليات معلقة ✅" : "معلق: " + pending + " عملية";
            SyncBadge.Foreground = pending == 0
                ? System.Windows.Media.Brushes.LightGreen
                : System.Windows.Media.Brushes.Orange;
        }

        private void UpdateLicenseBadge()
        {
            var planAr = _state.Plan == "trial" ? "تجريبي" : "مفعل";
            if (_state.Pro) planAr += " PRO";
            if (_state.ExpiresAt.HasValue)
            {
                var days = (int)(_state.ExpiresAt.Value - DateTimeOffset.UtcNow).TotalDays;
                planAr += days >= 0 ? " (" + days + " يوم)" : " (منتهي - فترة سماح)";
            }
            LicenseBadge.Text = planAr;
        }

        private async void SyncNow_Click(object sender, RoutedEventArgs e)
        {
            await SyncNow();
        }

        private async void DownloadCatalog_Click(object sender, RoutedEventArgs e)
        {
            if (!_isPharmacy) return;
            CatalogButton.IsEnabled = false;
            try
            {
                if (!await EnsureSession()) { CatalogStateText.Text = "سجّل الدخول أولاً (يحتاج إنترنت)"; return; }
                var syncer = new DrugCatalogSync(_sync);
                var total = 0;
                string after = null;
                for (var round = 0; round < 40; round++)
                {
                    var res = await syncer.DownloadAsync(_drugs, after, 1);
                    total += res.Rows;
                    after = res.LastId;
                    CatalogStateText.Text = "حُمل " + total + " دواء...";
                    if (res.Complete || res.Rows == 0) break;
                }
                CatalogStateText.Text = "اكتمل: " + _drugs.Count() + " دواء متاح بدون إنترنت";
            }
            catch (Exception ex)
            {
                CatalogStateText.Text = "تعذر التحميل: " + ex.Message;
            }
            finally { CatalogButton.IsEnabled = true; }
        }

        private void Network_Click(object sender, RoutedEventArgs e)
        {
            new NetworkWindow(new PharmacyNetworkClient(_sync, _state.MerchantId), _state.MerchantId)
            { Owner = this }.Show();
        }

        private void Pro_Click(object sender, RoutedEventArgs e)
        {
            new ProWindow(new ProClient(_sync, _state.MerchantId)) { Owner = this }.Show();
        }

        private void SignOut_Click(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show(this,
                    "سيُطلب التفعيل مرة أخرى عند التشغيل القادم. المبيعات المحلية تبقى. متابعة؟",
                    "تسجيل الخروج", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
                return;
            _activation.Deactivate();
            MessageBox.Show(this, "سُجل الخروج. أعد تشغيل البرنامج للتفعيل.", "تم",
                MessageBoxButton.OK, MessageBoxImage.Information);
            Application.Current.Shutdown();
        }
    }

    /// <summary>One shared HttpClient (socket reuse) for the app lifetime.</summary>
    internal sealed class HttpClientFactory
    {
        public readonly System.Net.Http.HttpClient Client = new System.Net.Http.HttpClient
        {
            Timeout = TimeSpan.FromSeconds(30),
        };
    }
}
