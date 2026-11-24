#if SCREENSHOT_TOUR
// CI screenshot instrumentation - compiled ONLY into the dedicated tour
// build (pos-windows.yml passes -p:DefineConstants to a separate output dir).
// The shipped cashier ZIP/installers are built without the symbol and a
// workflow step scans them to prove no tour marker survives.
//
// What this does, in a fully isolated synthetic scope (temp root, no
// activation, no seal, no production data - review #201):
//   1. Seeds a sample grocery dataset through the REAL data paths
//      (RetailCatalogCache.Upsert, PullApplier.Apply, PosLocalDb.CommitSale)
//      so screens show real content: 4 products, 1 customer with a debt,
//      1 completed sale.
//   2. Walks a fixed list of steps (5 tabs + payment, add-product and
//      receipt dialogs). Each step writes a one-shot ready-<slug> marker and
//      waits for the runner's ack-<slug> before advancing - capture and app
//      are synchronized, never timer-raced (review #202).
using System;
using System.Collections.Generic;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Wpf
{
    public partial class MainWindow
    {
        private static readonly (string Slug, int? TabIndex, string Dialog)[] TourSteps =
        {
            ("tab-sales", 0, null),
            ("tab-inventory", 1, null),
            ("tab-customers", 2, null),
            ("tab-shifts", 3, null),
            ("tab-settings", 4, null),
            ("dialog-payment", null, "payment"),
            ("dialog-addproduct", null, "addproduct"),
            ("dialog-receipt", null, "receipt"),
        };

        private string _tourDir;
        private int _tourStep;
        private bool _tourWaitingAck;
        private Window _tourDialog;

        // Started from the window's Loaded event (wired in MainWindow.xaml.cs),
        // after every field, control and dataset is initialized - never from
        // the constructor (reviewer order-of-init blocker).
        private void OnScreenshotTourLoaded(object sender, RoutedEventArgs e)
        {
            Loaded -= OnScreenshotTourLoaded;
            StartScreenshotTour();
        }

        internal void StartScreenshotTour()
        {
            _tourDir = Environment.GetEnvironmentVariable("DELWAQTY_TOUR_DIR")
                ?? Path.Combine(Path.GetTempPath(), "delwaqty-tour-markers");
            Directory.CreateDirectory(_tourDir);
            SeedTourDataset();
            var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(400) };
            timer.Tick += (s2, e2) => TourTick();
            timer.Start();
        }

        private void SeedTourDataset()
        {
            // A small grocery: four products on the shelf.
            _products.Upsert(new RetailProduct { Id = "tour-rice", Name = "Rice 1kg", NameAr = "أرز مصري ١ كجم", Price = 45m, Stock = 40m, Barcode = "6221000001", SearchNorm = "rice ارز", UpdatedAt = "2026-11-24T08:00:00Z" });
            _products.Upsert(new RetailProduct { Id = "tour-oil", Name = "Sunflower oil 700ml", NameAr = "زيت عباد الشمس ٧٠٠ مل", Price = 68m, Stock = 24m, Barcode = "6221000002", SearchNorm = "oil زيت", UpdatedAt = "2026-11-24T08:00:00Z" });
            _products.Upsert(new RetailProduct { Id = "tour-sugar", Name = "Sugar 1kg", NameAr = "سكر ١ كجم", Price = 30m, Stock = 55m, Barcode = "6221000003", SearchNorm = "sugar سكر", UpdatedAt = "2026-11-24T08:00:00Z" });
            _products.Upsert(new RetailProduct { Id = "tour-tea", Name = "Tea 100 bags", NameAr = "شاي ١٠٠ فتلة", Price = 55m, Stock = 18m, Barcode = "6221000004", SearchNorm = "tea شاي", UpdatedAt = "2026-11-24T08:00:00Z" });

            // One customer carrying a debt, through the real pull-apply path.
            var summary = PullApplier.Apply(
                "{\"server_time\":\"2026-11-24T08:00:00Z\",\"customers\":[" +
                "{\"id\":\"tour-c1\",\"name\":\"أم محمد\",\"phone\":\"01012345678\",\"balance\":120.50}]}",
                _products);
            _customers = summary.CustomerList;
            CustomersGrid.ItemsSource = _customers;

            // One completed cash sale in today's journal (2 rice + 1 oil).
            var sale = new SaleBuilder
            {
                ShiftId = "tour-shift-1",
                CustomerId = "tour-c1",
                CustomerName = "أم محمد",
            };
            sale.AddLine(new SaleLine { ProductId = "tour-rice", Name = "أرز مصري ١ كجم", Qty = 2, UnitPrice = 45m });
            sale.AddLine(new SaleLine { ProductId = "tour-oil", Name = "زيت عباد الشمس ٧٠٠ مل", Qty = 1, UnitPrice = 68m });
            sale.AddPayment("cash", 158m);
            sale.Close();
            _localDb.CommitSale(OutboxPayloads.Sale(sale), sale, "tour-shift-1");
            RefreshShiftSales();
        }

        private void TourTick()
        {
            if (_tourWaitingAck)
            {
                if (!File.Exists(Path.Combine(_tourDir, "ack-" + TourSteps[_tourStep].Slug))) return;
                _tourDialog?.Close();
                _tourDialog = null;
                _tourStep++;
                _tourWaitingAck = false;
                if (_tourStep >= TourSteps.Length)
                {
                    File.WriteAllText(Path.Combine(_tourDir, "tour-done"), "done");
                }
                return;
            }
            if (_tourStep >= TourSteps.Length) return;

            var (slug, tabIndex, dialog) = TourSteps[_tourStep];
            string proof;
            if (tabIndex.HasValue)
            {
                Tabs.SelectedIndex = tabIndex.Value;
                // The product grids are search-driven by design (queries under
                // two chars return nothing): type a query so the seeded
                // products are visible in the capture.
                if (tabIndex.Value == 0) SearchBox.Text = "أرز";
                else if (tabIndex.Value == 1) StockSearchBox.Text = "كجم";
                proof = "tab selected: " + ((TabItem)Tabs.Items[tabIndex.Value]).Header;
            }
            else
            {
                _tourDialog = OpenTourDialog(dialog);
                proof = "dialog open: " + dialog;
            }
            File.WriteAllText(Path.Combine(_tourDir, "ready-" + slug), proof);
            _tourWaitingAck = true;
        }

        private Window OpenTourDialog(string dialog)
        {
            Window w;
            if (dialog == "payment")
            {
                var paySale = new SaleBuilder();
                paySale.AddLine(new SaleLine { ProductId = "tour-sugar", Name = "سكر ١ كجم", Qty = 1, UnitPrice = 30m });
                paySale.AddLine(new SaleLine { ProductId = "tour-tea", Name = "شاي ١٠٠ فتلة", Qty = 1, UnitPrice = 55m });
                w = new PaymentDialog(paySale, () => _customers) { Owner = this };
            }
            else if (dialog == "addproduct")
            {
                w = new AddProductDialog(new ProductCreator(_sync, _state.MerchantId), _products) { Owner = this };
            }
            else
            {
                var receipt = "دلوقتي كاشير - متجر تجريبي\n" +
                    "--------------------------------\n" +
                    "أرز مصري ١ كجم   ×٢   ٩٠٫٠٠\n" +
                    "زيت عباد الشمس   ×١   ٦٨٫٠٠\n" +
                    "--------------------------------\n" +
                    "الإجمالي: ١٥٨٫٠٠ جنيه\n" +
                    "الدفع: كاش\nشكراً لتسوقكم معنا";
                w = new ReceiptWindow(receipt, "01012345678") { Owner = this };
            }
            w.Show();
            return w;
        }
    }
}
#endif
