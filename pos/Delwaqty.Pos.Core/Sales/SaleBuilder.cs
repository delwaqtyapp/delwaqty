using System;
using System.Collections.Generic;
using System.Linq;

namespace Delwaqty.Pos.Core.Sales
{
    public sealed class SaleLine
    {
        public string ProductId;       // null for quick lines not in the store's products
        public string Name;
        public decimal Qty;
        public decimal UnitPrice;
        public decimal DiscountAmount;
        public bool IsWeightBased;

        public decimal Total
        {
            get { return Math.Round(Qty * UnitPrice - DiscountAmount, 2, MidpointRounding.AwayFromZero); }
        }
    }

    public sealed class Payment
    {
        public string Method;   // cash | card | wallet | deferred
        public decimal Amount;

        public Payment(string method, decimal amount) { Method = method; Amount = amount; }
    }

    /// <summary>
    /// Offline sale math. Totals are computed on the client exactly as the server
    /// expects them in cashier_sync_push's 'sale' op (migration 340).
    /// </summary>
    public sealed class SaleBuilder
    {
        // Must mirror the pos_sale_payments CHECK constraint exactly
        // (migration 340, widened by 347): anything else fails server-side.
        public static readonly IReadOnlyCollection<string> AllowedMethods =
            new List<string> { "cash", "instapay", "vodafone_cash", "card", "deferred" };

        private static readonly HashSet<string> Methods =
            new HashSet<string>(AllowedMethods);

        private readonly List<SaleLine> _lines = new List<SaleLine>();
        private readonly List<Payment> _payments = new List<Payment>();

        public decimal DiscountAmount { get; private set; }
        public string CustomerId { get; set; }
        public string CustomerName { get; set; }
        public string Notes { get; set; }
        public string ShiftId { get; set; }

        public IReadOnlyList<SaleLine> Lines { get { return _lines; } }
        public IReadOnlyList<Payment> Payments { get { return _payments; } }

        public void AddLine(SaleLine line)
        {
            if (line == null) throw new ArgumentNullException("line");
            if (line.Qty <= 0) throw new ArgumentOutOfRangeException("line.Qty");
            if (line.UnitPrice < 0) throw new ArgumentOutOfRangeException("line.UnitPrice");
            if (string.IsNullOrWhiteSpace(line.Name)) throw new ArgumentException("line.Name required");
            _lines.Add(line);
        }

        public void SetDiscount(decimal amount)
        {
            if (amount < 0) throw new ArgumentOutOfRangeException("amount");
            DiscountAmount = Math.Round(amount, 2, MidpointRounding.AwayFromZero);
        }

        public void AddPayment(string method, decimal amount)
        {
            if (!Methods.Contains(method)) throw new ArgumentException("unknown method " + method);
            if (amount <= 0) throw new ArgumentOutOfRangeException("amount");
            _payments.Add(new Payment(method, Math.Round(amount, 2, MidpointRounding.AwayFromZero)));
        }

        public decimal Subtotal
        {
            get { return Math.Round(_lines.Sum(l => l.Total), 2, MidpointRounding.AwayFromZero); }
        }

        public decimal Total
        {
            get
            {
                var t = Subtotal - DiscountAmount;
                return t < 0 ? 0 : Math.Round(t, 2, MidpointRounding.AwayFromZero);
            }
        }

        public void RemoveLineAt(int index) { _lines.RemoveAt(index); }

        public void RemovePaymentAt(int index) { _payments.RemoveAt(index); }

        public void ClearPayments() { _payments.Clear(); }

        public decimal PaidAmount
        {
            get
            {
                return Math.Round(_payments.Where(p => p.Method != "deferred").Sum(p => p.Amount),
                    2, MidpointRounding.AwayFromZero);
            }
        }

        public decimal DeferredAmount
        {
            get { return Math.Round(Total - PaidAmount, 2, MidpointRounding.AwayFromZero); }
        }

        /// <summary>Reset to an empty sale (new transaction without losing settings).</summary>
        public void Reset()
        {
            _lines.Clear();
            _payments.Clear();
            DiscountAmount = 0;
            CustomerId = null;
            CustomerName = null;
            Notes = null;
        }

        /// <summary>Validate and auto-balance: adds a cash payment for any uncovered remainder.</summary>
        public void Close()
        {
            if (_lines.Count == 0) throw new InvalidOperationException("sale has no lines");
            var remainder = DeferredAmount;
            var declaredDeferred = _payments.Where(p => p.Method == "deferred").Sum(p => p.Amount);
            if (declaredDeferred > remainder + 0.001m)
                throw new InvalidOperationException("deferred exceeds uncovered remainder");
            if (remainder > 0)
            {
                if (declaredDeferred > 0 || CustomerId != null)
                {
                    if (CustomerId == null)
                        throw new InvalidOperationException("deferred sale requires a customer");
                    if (remainder > declaredDeferred + 0.001m)
                        _payments.Add(new Payment("deferred", remainder));
                }
                else
                {
                    _payments.Add(new Payment("cash", remainder));
                }
            }
            if (Math.Abs(_payments.Sum(p => p.Amount) - Total) > 0.011m)
                throw new InvalidOperationException("payments do not cover total");
        }
    }
}
