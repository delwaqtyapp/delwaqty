using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Windows;
using Delwaqty.Pos.Core.Pro;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>PRO features: insurance companies + statements, MoH prices, shortages.</summary>
    public partial class ProWindow : Window
    {
        public sealed class CompanyRow
        {
            public string Id;
            public string Name { get; set; }
            public string Phone { get; set; }
            public string Notes { get; set; }
        }

        public sealed class ShortageRow
        {
            public string Name { get; set; }
            public string Stock { get; set; }
            public string Level { get; set; }
        }

        private readonly ProClient _pro;

        public ProWindow(ProClient pro)
        {
            InitializeComponent();
            _pro = pro;
        }

        private async void Window_Loaded(object sender, RoutedEventArgs e)
        {
            await LoadCompanies();
        }

        private async System.Threading.Tasks.Task LoadCompanies()
        {
            try
            {
                var json = await _pro.InsuranceCompaniesAsync();
                var rows = new List<CompanyRow>();
                using (var doc = JsonDocument.Parse(json))
                {
                    foreach (var el in doc.RootElement.EnumerateArray())
                    {
                        rows.Add(new CompanyRow
                        {
                            Id = Str(el, "id"),
                            Name = Str(el, "name"),
                            Phone = Str(el, "phone"),
                            Notes = Str(el, "notes"),
                        });
                    }
                }
                CompaniesGrid.ItemsSource = rows;
                StatusText.Text = "آخر تحديث: " + DateTime.Now.ToString("HH:mm");
            }
            catch (Exception ex) { StatusText.Text = "تعذر التحميل: " + ex.Message; }
        }

        private async void AddCompany_Click(object sender, RoutedEventArgs e)
        {
            var name = (CoNameBox.Text ?? "").Trim();
            if (name.Length == 0) { StatusText.Text = "اكتب اسم الشركة"; return; }
            try
            {
                await _pro.InsuranceCompanyCreateAsync(name, (CoPhoneBox.Text ?? "").Trim(), null);
                CoNameBox.Clear(); CoPhoneBox.Clear();
                await LoadCompanies();
            }
            catch (Exception ex) { StatusText.Text = "تعذرت الإضافة: " + ex.Message; }
        }

        private async void Statement_Click(object sender, RoutedEventArgs e)
        {
            var co = CompaniesGrid.SelectedItem as CompanyRow;
            if (co == null) { StatusText.Text = "اختر شركة أولاً"; return; }
            try
            {
                var now = DateTimeOffset.Now;
                var json = await _pro.InsuranceStatementAsync(co.Id, now.AddMonths(-1), now);
                MessageBox.Show(this, Pretty(json), "كشف حساب - " + co.Name,
                    MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex) { StatusText.Text = "تعذر الكشف: " + ex.Message; }
        }

        private async void ApplyMoh_Click(object sender, RoutedEventArgs e)
        {
            if (MessageBox.Show(this, "سيتم تحديث أسعار الأصناف المطابقة للتسعيرة الرسمية. متابعة؟",
                    "التسعيرة الرسمية", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
                return;
            try
            {
                var json = await _pro.ApplyMohPricesAsync();
                StatusText.Text = "تم التطبيق: " + Pretty(json);
            }
            catch (Exception ex) { StatusText.Text = "تعذر التطبيق: " + ex.Message; }
        }

        private async void Shortage_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var json = await _pro.ShortageListAsync(3);
                var rows = new List<ShortageRow>();
                using (var doc = JsonDocument.Parse(json))
                {
                    JsonElement arr = doc.RootElement;
                    if (arr.ValueKind == JsonValueKind.Object && arr.TryGetProperty("shortages", out var s)) arr = s;
                    if (arr.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var el in arr.EnumerateArray())
                        {
                            rows.Add(new ShortageRow
                            {
                                Name = Str(el, "name") ?? Str(el, "name_ar"),
                                Stock = DecStr(el, "stock") ?? DecStr(el, "stock_quantity"),
                                Level = DecStr(el, "reorder_level"),
                            });
                        }
                    }
                }
                ShortageGrid.ItemsSource = rows;
                StatusText.Text = rows.Count == 0 ? "لا توجد نواقص" : "عدد النواقص: " + rows.Count;
            }
            catch (Exception ex) { StatusText.Text = "تعذر التحميل: " + ex.Message; }
        }

        private static string Pretty(string json)
        {
            try
            {
                using (var doc = JsonDocument.Parse(json))
                    return JsonSerializer.Serialize(doc.RootElement, new JsonSerializerOptions { WriteIndented = true });
            }
            catch { return json; }
        }

        private static string Str(JsonElement el, string name)
        {
            return el.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        }

        private static string DecStr(JsonElement el, string name)
        {
            if (!el.TryGetProperty(name, out var v)) return null;
            if (v.ValueKind == JsonValueKind.Number && v.TryGetDecimal(out var d)) return d.ToString("0.##");
            if (v.ValueKind == JsonValueKind.String) return v.GetString();
            return null;
        }
    }
}
