using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace Delwaqty.Pos.Core.Sales
{
    /// <summary>
    /// Builds the plain-text receipt (80mm thermal, ~42 columns) for a closed
    /// sale. Pure function: same input, same receipt, so tests pin the format.
    /// Arabic labels; amounts right-aligned in Latin digits (what Egyptian
    /// thermal printers render reliably).
    /// </summary>
    public static class ReceiptBuilder
    {
        public const int Width = 42;

        public sealed class Context
        {
            public string StoreName;
            public string StorePhone;
            public string StoreAddress;
            public string SaleId;            // short reference (op id prefix)
            public DateTimeOffset When;
            public string CustomerName;      // for deferred sales
            public string CashierNote;
            public bool IsPharmacy;
        }

        public static string MethodLabel(string method)
        {
            switch (method)
            {
                case "cash": return "نقدي";
                case "instapay": return "انستاباي";
                case "vodafone_cash": return "فودافون كاش";
                case "card": return "بطاقة";
                case "deferred": return "آجل";
                default: return method;
            }
        }

        public static string Build(Context ctx, SaleBuilder sale)
        {
            var sb = new StringBuilder();
            sb.AppendLine(Center(ctx.StoreName ?? "دلوقتي"));
            if (!string.IsNullOrWhiteSpace(ctx.StoreAddress)) sb.AppendLine(Center(ctx.StoreAddress));
            if (!string.IsNullOrWhiteSpace(ctx.StorePhone)) sb.AppendLine(Center("ت: " + ctx.StorePhone));
            sb.AppendLine(Line('-'));
            sb.AppendLine("فاتورة بيع" + (ctx.SaleId != null ? "  #" + ctx.SaleId : ""));
            sb.AppendLine(ctx.When.ToLocalTime().ToString("yyyy/MM/dd  hh:mm tt", CultureInfo.InvariantCulture));
            if (!string.IsNullOrWhiteSpace(ctx.CustomerName)) sb.AppendLine("العميل: " + ctx.CustomerName);
            sb.AppendLine(Line('-'));
            sb.AppendLine(Pad("الصنف", "كمية", "سعر", "قيمة"));
            sb.AppendLine(Line('-'));
            foreach (var l in sale.Lines)
            {
                sb.AppendLine(TrimTo(l.Name, Width));
                sb.AppendLine("   " + Pad("", Fmt(l.Qty), Fmt(l.UnitPrice), Fmt(l.Total)));
            }
            sb.AppendLine(Line('-'));
            sb.AppendLine(RowTotal("الإجمالي قبل الخصم", sale.Subtotal));
            if (sale.DiscountAmount > 0) sb.AppendLine(RowTotal("الخصم", -sale.DiscountAmount));
            sb.AppendLine(RowTotal("الإجمالي المستحق", sale.Total));
            foreach (var p in sale.Payments)
                sb.AppendLine(RowTotal(MethodLabel(p.Method), p.Amount));
            if (sale.DeferredAmount > 0.001m)
                sb.AppendLine(RowTotal("متبقي آجل", sale.DeferredAmount));
            if (!string.IsNullOrWhiteSpace(ctx.CashierNote)) sb.AppendLine(ctx.CashierNote);
            sb.AppendLine(Line('='));
            sb.AppendLine(Center("شكراً لتعاملكم معنا"));
            if (ctx.IsPharmacy)
                sb.AppendLine(Center("الاستعمال حسب إرشادات الطبيب أو الصيدلي"));
            return sb.ToString();
        }

        private static string Fmt(decimal v)
        {
            return v.ToString("0.##", CultureInfo.InvariantCulture);
        }

        private static string RowTotal(string label, decimal amount)
        {
            var value = Fmt(amount);
            var spaces = Width - DisplayLen(label) - value.Length;
            return label + (spaces > 1 ? new string(' ', spaces) : " ") + value;
        }

        private static string Pad(string a, string b, string c, string d)
        {
            // 4 columns: name (wide), qty, price, total — fixed rough widths.
            var s = TrimTo(a, 20);
            s = s.PadRight(20 + (DisplayLen(a) - a.Length)) ;
            s += PadLeft(b, 6) + PadLeft(c, 8) + PadLeft(d, 8);
            return TrimTo(s, Width);
        }

        private static string PadLeft(string s, int w)
        {
            return s.Length >= w ? s : new string(' ', w - s.Length) + s;
        }

        private static string TrimTo(string s, int w)
        {
            if (s == null) return "";
            return s.Length <= w ? s : s.Substring(0, w);
        }

        private static int DisplayLen(string s)
        {
            return s == null ? 0 : s.Length;
        }

        private static string Center(string s)
        {
            if (s == null) return "";
            if (s.Length >= Width) return s;
            var pad = (Width - s.Length) / 2;
            return new string(' ', pad) + s;
        }

        private static string Line(char c)
        {
            return new string(c, Width);
        }
    }
}
