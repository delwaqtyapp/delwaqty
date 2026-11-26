using System;
using System.Windows;
using Delwaqty.Pos.Core.Catalog;
using Delwaqty.Pos.Core.Sales;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>Retail item entry. Online only (products table write); the
    /// new product lands in the local cache immediately on success.</summary>
    public partial class AddProductDialog : Window
    {
        private readonly ProductCreator _creator;
        private readonly RetailCatalogCache _cache;
        public string CreatedProductId { get; private set; }

        public AddProductDialog(ProductCreator creator, RetailCatalogCache cache)
        {
            InitializeComponent();
            _creator = creator;
            _cache = cache;
        }

        private async void Save_Click(object sender, RoutedEventArgs e)
        {
            decimal price;
            int stock;
            if (!decimal.TryParse(PriceBox.Text, out price) || price < 0)
            {
                MessageBox.Show(this, "أدخل سعراً صحيحاً", "إضافة صنف",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            if (!int.TryParse(StockBox.Text, out stock) || stock < 0) stock = 0;
            try
            {
                CreatedProductId = await _creator.CreateAsync(_cache,
                    NameEnBox.Text, NameArBox.Text, price, stock, BarcodeBox.Text);
                DialogResult = true;
                Close();
            }
            catch (Exception ex)
            {
                MessageBox.Show(this,
                    "تعذر حفظ الصنف (يحتاج إنترنت). التفاصيل: " + ex.Message, "إضافة صنف",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
            }
        }

        private void Cancel_Click(object sender, RoutedEventArgs e) { DialogResult = false; Close(); }
    }
}
