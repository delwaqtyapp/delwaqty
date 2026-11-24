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
        /// <summary>One search hit, wrapping a store product.</summary>
        public sealed class SearchRow
        {
            public string ProductId;        // store product id
            public string DisplayName { get; set; }
            public string DisplayPrice { get; set; }
            public string DisplayStock { get; set; }
            public string Barcode { get; set; }
            public decimal Price;
        }

        private readonly ActivationService _activation;
        private readonly ActivationState _state;
        private readonly string _dataDir;   // the merchant+flavor scope dir (#116)

        private readonly HttpClientFactory _http = new HttpClientFactory();
        private readonly SyncClient _sync;
        private readonly AuthClient _auth;
        private AuthSession _session;

        private readonly RetailCatalogCache _products;   // store products
        private readonly PosLocalDb _localDb;            // outbox + journal, one db (#120)
        private readonly SyncEngine _engine;
        private readonly LicenseRefresher _licenseRefresher;
        private PosMode _mode = PosMode.Full;

        private readonly SaleBuilder _sale = new SaleBuilder();
        private readonly ObservableCollection<SaleLine> _cart = new ObservableCollection<SaleLine>();
        private List<PullApplier.PosCustomer> _customers = new List<PullApplier.PosCustomer>();
        private string _currentShiftId;   // local grouping id (op id until adopted)
        private string _serverShiftId;    // real pos_shifts id once the shift_open synced
        private decimal _currentFloat;
        private readonly DispatcherTimer _syncTimer;
        private readonly DispatcherTimer _clockTimer;
        private bool _syncing;

        public MainWindow(ActivationService activation, ActivationState state)
        {
            InitializeComponent();
            _activation = activation;
            _dataDir = activation.CurrentScopeDir;
            _state = state;

            _sync = new SyncClient(PosConfig.SupabaseUrl, PosConfig.SupabaseAnonKey, _http.Client);
            _auth = new AuthClient(PosConfig.SupabaseUrl, PosConfig.SupabaseAnonKey, _http.Client);
            _products = new RetailCatalogCache(Path.Combine(_dataDir, "products.db"));
            _localDb = new PosLocalDb(Path.Combine(_dataDir, "pos.db"));
            _engine = new SyncEngine(_localDb.Outbox, _sync, state.MerchantId);
            _licenseRefresher = new LicenseRefresher(activation, _sync);
            _mode = LicenseGuard.Evaluate(state, DateTimeOffset.UtcNow);

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
            Closed += (s, e) => { _syncTimer.Stop(); _clockTimer.Stop(); _localDb.Dispose(); };
            ApplyMode();
        }

        // ==================== LICENSE MODE (#119) ====================

        private void ApplyMode()
        {
            if (_mode == PosMode.Locked)
            {
                StatusText.Text = "الترخيص موقوف أو منتهي — البيع متوقف. بياناتك محفوظة وتُرفع عند التجديد.";
            }
            else if (_mode == PosMode.Grace)
            {
                StatusText.Text = "الترخيص منتهي — فترة سماح. جدد الاشتراك قريباً.";
            }
            UpdateLicenseBadge();
        }

        private bool EnsureSellingAllowed()
        {
            // #120 migration: a failed legacy import means local data is in a
            // repair state — never sell on top of it.
            if (_localDb.RepairState != null)
            {
                MessageBox.Show(this,
                    "ترقية البيانات المحلية تحتاج إصلاحاً — تواصل مع الدعم قبل البيع. بياناتك القديمة محفوظة كما هي.",
                    "إصلاح البيانات", MessageBoxButton.OK, MessageBoxImage.Warning);
                return false;
            }
            // #119 follow-up: re-evaluate against the clock on EVERY mutation,
            // independent of network or the refresh timer — an offline session
            // must stop selling the moment expiry/grace passes.
            var nowMode = LicenseGuard.Evaluate(_state, DateTimeOffset.UtcNow);
            if (nowMode != _mode) { _mode = nowMode; ApplyMode(); }
            if (_mode != PosMode.Locked) return true;
            MessageBox.Show(this,
                "الترخيص موقوف أو منتهي. البيع متوقف حتى التجديد — البيانات المحلية محفوظة.",
                "الترخيص", MessageBoxButton.OK, MessageBoxImage.Warning);
            return false;
        }

        private void ConfigureFlavor()
        {
            TitleText.Text = PosConfig.DefaultTitle;
            StoreText.Text = _state.MerchantName ?? "";
            SearchHint.Text = "ابحث بالاسم أو الباركود — Enter يضيف أول نتيجة";
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
            var line = new SaleLine
            {
                ProductId = row.ProductId,
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
            if (!EnsureSellingAllowed()) return;
            if (_sale.Lines.Count == 0)
            {
                CartNote.Text = "الفاتورة فارغة";
                return;
            }
            // The payload carries the server shift id when known, else the
            // local shift op id — the sync engine rewrites it through the
            // shift map before pushing (#117).
            _sale.ShiftId = _serverShiftId ?? _currentShiftId;
            var dlg = new PaymentDialog(_sale, () => _customers) { Owner = this };
            if (dlg.ShowDialog() != true) return;

            // #119 follow-up: the dialog can stay open across a grace cutoff
            // or a suspension — re-evaluate the license AFTER it closes and
            // BEFORE anything is committed.
            if (!EnsureSellingAllowed()) return;

            // A brand-new customer from the payment dialog gets a stable
            // client id (the op id); the sale already references it (#118).
            if (dlg.NewCustomer != null)
            {
                _localDb.Outbox.Enqueue(OutboxPayloads.Customer(dlg.NewCustomer.NewCustomerName,
                    dlg.NewCustomer.NewCustomerPhone, null, dlg.NewCustomerClientId));
            }

            var op = OutboxPayloads.Sale(_sale);
            // #120: outbox op + journal row in ONE transaction — a crash
            // cannot record a sale without its outbox op.
            _localDb.CommitSale(op, _sale, _currentShiftId);

            var receipt = ReceiptBuilder.Build(new ReceiptBuilder.Context
            {
                StoreName = _state.MerchantName,
                StorePhone = _state.MerchantPhone,
                StoreAddress = _state.MerchantAddress,
                SaleId = op.OpId.Substring(0, 8),
                When = DateTimeOffset.Now,
                CustomerName = _sale.CustomerName,
            }, _sale);
            var phone = dlg.NewCustomer != null
                ? dlg.NewCustomer.NewCustomerPhone
                : (_sale.CustomerId != null
                    ? (_customers.FirstOrDefault(c => c.Id == _sale.CustomerId) ?? new PullApplier.PosCustomer()).Phone
                    : null);

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
            _localDb.Outbox.Enqueue(OutboxPayloads.StockCount(row.ProductId, counted, "جرد يدوي"));
            var cached = _products.ById(row.ProductId);
            if (cached != null) { cached.Stock = counted; _products.Upsert(cached); }
            StatusText.Text = "سُجل جرد: " + row.DisplayName;
            UpdateSyncBadge();
            StockResults.ItemsSource = DoSearch(StockSearchBox.Text);
        }

        private void AddProduct_Click(object sender, RoutedEventArgs e)
        {
            var creator = new ProductCreator(_sync, _state.MerchantId);
            var dlg = new AddProductDialog(creator, _products) { Owner = this };
            dlg.ShowDialog();
        }

        private void PriceChange_Click(object sender, RoutedEventArgs e)
        {
            if (!EnsureSellingAllowed()) return; // price mutation: license-gated
            var row = StockResults.SelectedItem as SearchRow;
            if (row == null || row.ProductId == null) { StatusText.Text = "اختر صنفاً مسجلاً أولاً"; return; }
            var price = InputDialog.AskAmount(this, "تغيير السعر", "السعر الجديد:", row.Price.ToString("0.##"));
            if (!price.HasValue) return;
            _localDb.Outbox.Enqueue(OutboxPayloads.PriceChange(row.ProductId, price.Value, "manual"));
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
            _localDb.Outbox.Enqueue(OutboxPayloads.BulkPricePct(pct.Value));
            StatusText.Text = "سُجلت زيادة " + pct.Value + "% (تُطبق عند المزامنة)";
            UpdateSyncBadge();
        }

        // ==================== CUSTOMERS & DEBTS ====================

        private void SaveCustomer_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(CustomerNameBox.Text))
            {
                StatusText.Text = "اكتب اسم العميل";
                return;
            }
            _localDb.Outbox.Enqueue(OutboxPayloads.Customer(CustomerNameBox.Text.Trim(),
                (CustomerPhoneBox.Text ?? "").Trim(), null));
            StatusText.Text = "حُفظ العميل (يُرفع عند الاتصال)";
            CustomerNameBox.Clear(); CustomerPhoneBox.Clear();
            UpdateSyncBadge();
        }

        private void DebtPayment_Click(object sender, RoutedEventArgs e)
        {
            // License-gate EXEMPTION (deliberate, review #119): recording a
            // customer's repayment is a recovery op — it only reduces what is
            // owed and never sells stock, so it stays available while locked.
            // Selling, stock intake and price changes ARE gated; reversals
            // (void below) and recoveries (here) are not.
            var c = CustomersGrid.SelectedItem as PullApplier.PosCustomer;
            if (c == null) { StatusText.Text = "اختر عميلاً من القائمة"; return; }
            var amount = InputDialog.AskAmount(this, "تحصيل دفعة",
                "المبلغ المحصل من " + c.Name + " (دينه الحالي " + c.Balance.ToString("0.##") + "):", "");
            if (!amount.HasValue || amount.Value <= 0) return;
            _localDb.Outbox.Enqueue(OutboxPayloads.DebtPayment(c.Id, amount.Value, null));
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
                        // Older builds stored a single pending close cash here
                        // (#117 removed the scalar — closes are queued ops now).
                        if (parts.Length >= 4)
                        {
                            decimal pc;
                            if (decimal.TryParse(parts[3], out pc) &&
                                (_serverShiftId ?? _currentShiftId) != null)
                            {
                                _localDb.Outbox.Enqueue(OutboxPayloads.DailyClose(
                                    _serverShiftId ?? _currentShiftId, pc));
                            }
                        }
                    }
                }
            }
            catch { _currentShiftId = null; _serverShiftId = null; }
            RefreshShiftUi();
        }

        private void SaveShiftState()
        {
            if (_currentShiftId == null)
            {
                if (File.Exists(ShiftPath)) File.Delete(ShiftPath);
                return;
            }
            File.WriteAllText(ShiftPath,
                (_currentShiftId ?? "") + "|" + _currentFloat + "|" +
                (_serverShiftId ?? ""));
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
            var result = DailyCloseCalculator.Compute(_currentFloat, _localDb.Sales.CloseRecordsFor(_currentShiftId), null);
            ExpectedCashText.Text = result.ExpectedCash.ToString("0.##");
        }

        private void OpenShift_Click(object sender, RoutedEventArgs e)
        {
            if (_currentShiftId != null) { StatusText.Text = "توجد وردية مفتوحة بالفعل"; return; }
            decimal floatAmount;
            if (!decimal.TryParse(FloatBox.Text, out floatAmount) || floatAmount < 0) floatAmount = 0;
            var op = OutboxPayloads.ShiftOpen(floatAmount);
            _localDb.Outbox.Enqueue(op);
            _currentShiftId = op.OpId;   // local id; the server id is mapped on sync (#117)
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
                _localDb.Sales.CloseRecordsFor(_currentShiftId), closing);
            // #117: always queue the close immediately, keyed by whichever
            // shift id we know. The sync engine resolves a local id through
            // the shift map after the shift_open op syncs — no scalar state,
            // so a second shift works the same way.
            _localDb.Outbox.Enqueue(OutboxPayloads.DailyClose(_serverShiftId ?? _currentShiftId, closing));
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
            var rows = (_currentShiftId == null ? _localDb.Sales.Recent(50) : _localDb.Sales.SalesForShift(_currentShiftId))
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
            // License-gate EXEMPTION (deliberate, review #119): a void is a
            // reversal — it restores stock and must stay possible while
            // locked, or locked shops could never correct a mistaken sale.
            var row = ShiftSalesGrid.SelectedItem as ShiftSaleRow;
            if (row == null) { StatusText.Text = "اختر فاتورة أولاً"; return; }
            if (row.StatusAr == "ملغاة") { StatusText.Text = "الفاتورة ملغاة بالفعل"; return; }
            var reason = InputDialog.Ask(this, "إلغاء فاتورة", "سبب الإلغاء:", "خطأ في الإدخال");
            if (reason == null) return;
            // #120: void op + journal mark, atomically.
            _localDb.VoidSale(OutboxPayloads.SaleVoid(row.OpId, reason), row.OpId);
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
                // #119 follow-up: the license clock is evaluated on every
                // sync tick BEFORE any network step — a failed session
                // refresh must never leave a stale mode past expiry/grace.
                var clockMode = LicenseGuard.Evaluate(_state, DateTimeOffset.UtcNow);
                if (clockMode != _mode) { _mode = clockMode; ApplyMode(); }

                if (_localDb.RepairState != null) { UpdateSyncBadge(); return; }
                if (!await EnsureSession()) { UpdateSyncBadge(); return; }

                // #119: periodic verified license refresh — a suspension or
                // expiry decided on the server reaches a running app within
                // the refresh interval, not only at the next restart. The
                // mode is re-evaluated after ANY outcome: refreshed, denied,
                // or skipped (null) — the clock moved regardless.
                var refreshed = await _licenseRefresher.RefreshAsync(_state, DateTimeOffset.UtcNow);
                var newMode = refreshed != null
                    ? refreshed.Mode
                    : LicenseGuard.Evaluate(_state, DateTimeOffset.UtcNow);
                if (newMode != _mode)
                {
                    _mode = newMode;
                    ApplyMode();
                }

                var flush = await _engine.FlushAsync();
                if (flush.RepricedLines > 0 || flush.ClientPricedLines > 0)
                    StatusText.Text = "السيرفر حدّث " + flush.RepricedLines + " سعراً؛ " +
                        flush.ClientPricedLines + " صنفاً بسعرك (قيد المراجعة)";

                // #117: adopt the server shift ids the flush resolved; remap
                // the local journal so shifts group by the server id.
                foreach (var pair in flush.ResolvedShifts)
                {
                    _localDb.Sales.RemapShift(pair.Key, pair.Value);
                    if (_currentShiftId == pair.Key)
                    {
                        _currentShiftId = pair.Value;
                        _serverShiftId = pair.Value;
                        SaveShiftState();
                        RefreshShiftUi();
                    }
                }

                var pull = await _sync.Pull(_state.MerchantId, null);
                var summary = PullApplier.Apply(pull, _products);
                _customers = summary.CustomerList;
                CustomersGrid.ItemsSource = _customers;
                if (summary.OpenShiftId != null && _currentShiftId == null)
                {
                    // A shift opened on another device: adopt it locally.
                    _currentShiftId = summary.OpenShiftId;
                    _serverShiftId = summary.OpenShiftId;
                    SaveShiftState();
                    RefreshShiftUi();
                }
                SyncDetailText.Text = "آخر مزامنة: " + DateTime.Now.ToString("HH:mm:ss") +
                    " — أصناف: " + summary.Products + "، عملاء: " + summary.Customers +
                    (flush.Failures.Count > 0 ? "\nعمليات فشلت: " + flush.Failures.Count : "") +
                    (flush.Blocked > 0 ? "\nعمليات تنتظر اكتمال المزامنة: " + flush.Blocked : "");
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
            var pending = _localDb.Outbox.PendingCount();
            SyncBadge.Text = pending == 0 ? "لا عمليات معلقة ✅" : "معلق: " + pending + " عملية";
            SyncBadge.Foreground = pending == 0
                ? System.Windows.Media.Brushes.LightGreen
                : System.Windows.Media.Brushes.Orange;
        }

        private void UpdateLicenseBadge()
        {
            if (_mode == PosMode.Locked)
            {
                LicenseBadge.Text = _state.Status == "suspended" ? "موقوف ⛔" : "منتهي ⛔";
                return;
            }
            var planAr = _state.Plan == "trial" ? "تجريبي" : "مفعل";
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
