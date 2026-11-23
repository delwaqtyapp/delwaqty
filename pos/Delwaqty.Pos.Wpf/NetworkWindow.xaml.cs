using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Windows;
using Delwaqty.Pos.Core.Network;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>
    /// Inter-pharmacy shortage exchange UI. Online only. Settlement is
    /// two-phase: one side proposes, the other confirms (migration 348).
    /// </summary>
    public partial class NetworkWindow : Window
    {
        public sealed class LinkRow
        {
            public string LinkId;
            public string MerchantId;
            public string Name { get; set; }
            public string Phone { get; set; }
            public string Balance { get; set; }
        }

        public sealed class TransferRow
        {
            public string Id;
            public string RequestingMerchant;
            public string ItemName { get; set; }
            public string Qty { get; set; }
            public string StatusAr { get; set; }
            public string Status;
            public string CashValue { get; set; }
        }

        private readonly PharmacyNetworkClient _client;
        private readonly string _merchantId;

        public NetworkWindow(PharmacyNetworkClient client, string merchantId)
        {
            InitializeComponent();
            _client = client;
            _merchantId = merchantId;
        }

        private async void Refresh_Click(object sender, RoutedEventArgs e)
        {
            StatusText.Text = "جاري التحميل...";
            try
            {
                var linksJson = await _client.DirectoryAsync();
                var links = new List<LinkRow>();
                using (var doc = JsonDocument.Parse(linksJson))
                {
                    foreach (var el in doc.RootElement.EnumerateArray())
                    {
                        links.Add(new LinkRow
                        {
                            LinkId = Str(el, "link_id"),
                            MerchantId = Str(el, "merchant_id"),
                            Name = Str(el, "name"),
                            Phone = Str(el, "phone"),
                            Balance = DecStr(el, "balance"),
                        });
                    }
                }
                LinksGrid.ItemsSource = links;

                var transfersJson = await _client.TransfersAsync();
                var transfers = new List<TransferRow>();
                using (var doc = JsonDocument.Parse(transfersJson))
                {
                    foreach (var el in doc.RootElement.EnumerateArray())
                    {
                        var status = Str(el, "status");
                        transfers.Add(new TransferRow
                        {
                            Id = Str(el, "id"),
                            RequestingMerchant = Str(el, "requesting_merchant"),
                            ItemName = Str(el, "item_name"),
                            Qty = DecStr(el, "qty"),
                            Status = status,
                            StatusAr = StatusArabic(status),
                            CashValue = DecStr(el, "agreed_cash_value"),
                        });
                    }
                }
                TransfersGrid.ItemsSource = transfers;
                StatusText.Text = "آخر تحديث: " + DateTime.Now.ToString("HH:mm");
            }
            catch (Exception ex)
            {
                StatusText.Text = "تعذر التحميل (يحتاج إنترنت): " + ex.Message;
            }
        }

        private static string StatusArabic(string status)
        {
            switch (status)
            {
                case "requested": return "مطلوب";
                case "accepted": return "مقبول";
                case "rejected": return "مرفوض";
                case "handed_over": return "تم التسليم";
                case "settlement_pending": return "بانتظار تأكيد التسوية";
                case "settled": return "مُسوّى";
                case "cancelled": return "ملغي";
                default: return status;
            }
        }

        private LinkRow SelectedLink { get { return LinksGrid.SelectedItem as LinkRow; } }
        private TransferRow SelectedTransfer { get { return TransfersGrid.SelectedItem as TransferRow; } }

        private async void NewRequest_Click(object sender, RoutedEventArgs e)
        {
            var link = SelectedLink;
            if (link == null) { StatusText.Text = "اختر صيدلية أولاً"; return; }
            var item = InputDialog.Ask(this, "طلب صنف ناقص", "اسم الصنف المطلوب:", "");
            if (string.IsNullOrWhiteSpace(item)) return;
            var qty = InputDialog.AskAmount(this, "طلب صنف ناقص", "الكمية:", "1");
            if (!qty.HasValue || qty.Value <= 0) return;
            var note = InputDialog.Ask(this, "طلب صنف ناقص", "ملاحظة (اختياري):", "");
            try
            {
                await _client.TransferRequestAsync(link.LinkId, item.Trim(), qty.Value, null, note);
                StatusText.Text = "أُرسل الطلب";
                Refresh_Click(sender, e);
            }
            catch (Exception ex) { StatusText.Text = "تعذر إرسال الطلب: " + ex.Message; }
        }

        private async void Accept_Click(object sender, RoutedEventArgs e)
        {
            var t = SelectedTransfer;
            if (t == null) return;
            var cash = InputDialog.AskAmount(this, "قبول الطلب", "قيمة نقدية متفق عليها (اختياري، 0 = بدون):", "0");
            try
            {
                await _client.TransferRespondAsync(t.Id, true, cash.HasValue && cash.Value > 0 ? cash : (decimal?)null);
                Refresh_Click(sender, e);
            }
            catch (Exception ex) { StatusText.Text = "تعذر القبول: " + ex.Message; }
        }

        private async void Reject_Click(object sender, RoutedEventArgs e)
        {
            var t = SelectedTransfer;
            if (t == null) return;
            try { await _client.TransferRespondAsync(t.Id, false, null); Refresh_Click(sender, e); }
            catch (Exception ex) { StatusText.Text = "تعذر الرفض: " + ex.Message; }
        }

        private async void Handover_Click(object sender, RoutedEventArgs e)
        {
            var t = SelectedTransfer;
            if (t == null) return;
            try { await _client.TransferHandoverAsync(t.Id, null); Refresh_Click(sender, e); }
            catch (Exception ex) { StatusText.Text = "تعذر تسجيل التسليم: " + ex.Message; }
        }

        private async void SettleSwap_Click(object sender, RoutedEventArgs e)
        {
            var t = SelectedTransfer;
            if (t == null) return;
            var desc = InputDialog.Ask(this, "تسوية بدل", "وصف البدل (مثال: علبتين بنادول):", "");
            if (string.IsNullOrWhiteSpace(desc)) return;
            try
            {
                await _client.TransferSettleAsync(t.Id, "swap", null, desc.Trim());
                StatusText.Text = "اقتراح التسوية أُرسل — بانتظار تأكيد الطرف الآخر";
                Refresh_Click(sender, e);
            }
            catch (Exception ex) { StatusText.Text = "تعذرت التسوية: " + ex.Message; }
        }

        private async void SettleCash_Click(object sender, RoutedEventArgs e)
        {
            var t = SelectedTransfer;
            if (t == null) return;
            var cash = InputDialog.AskAmount(this, "تسوية نقدية", "المبلغ النقدي:", t.CashValue ?? "0");
            if (!cash.HasValue) return;
            try
            {
                await _client.TransferSettleAsync(t.Id, "cash", cash.Value, null);
                StatusText.Text = "اقتراح التسوية أُرسل — بانتظار تأكيد الطرف الآخر";
                Refresh_Click(sender, e);
            }
            catch (Exception ex) { StatusText.Text = "تعذرت التسوية: " + ex.Message; }
        }

        private async void ConfirmSettle_Click(object sender, RoutedEventArgs e)
        {
            var t = SelectedTransfer;
            if (t == null) return;
            try { await _client.TransferSettleConfirmAsync(t.Id, true); Refresh_Click(sender, e); }
            catch (Exception ex) { StatusText.Text = "تعذر تأكيد التسوية: " + ex.Message; }
        }

        private async void RejectSettle_Click(object sender, RoutedEventArgs e)
        {
            var t = SelectedTransfer;
            if (t == null) return;
            try { await _client.TransferSettleConfirmAsync(t.Id, false); Refresh_Click(sender, e); }
            catch (Exception ex) { StatusText.Text = "تعذر رفض التسوية: " + ex.Message; }
        }

        private async void Message_Click(object sender, RoutedEventArgs e)
        {
            await LoadMessages();
        }

        private async void Link_Selected(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
        {
            await LoadMessages();
        }

        private void Transfer_Selected(object sender, System.Windows.Controls.SelectionChangedEventArgs e) { }

        private async System.Threading.Tasks.Task LoadMessages()
        {
            var link = SelectedLink;
            if (link == null) return;
            try
            {
                var json = await _client.MessagesAsync(link.LinkId);
                var lines = new List<string>();
                using (var doc = JsonDocument.Parse(json))
                {
                    foreach (var el in doc.RootElement.EnumerateArray())
                    {
                        var mine = Str(el, "sender_merchant") == _merchantId;
                        lines.Add((mine ? "أنا: " : link.Name + ": ") + Str(el, "body"));
                    }
                }
                MessagesList.ItemsSource = lines;
            }
            catch { /* messages are best-effort */ }
        }

        private async void SendMessage_Click(object sender, RoutedEventArgs e)
        {
            var link = SelectedLink;
            var body = (MessageBox.Text ?? "").Trim();
            if (link == null || body.Length == 0) return;
            try
            {
                await _client.MessageSendAsync(link.LinkId, body, null);
                MessageBox.Clear();
                await LoadMessages();
            }
            catch (Exception ex) { StatusText.Text = "تعذر الإرسال: " + ex.Message; }
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
