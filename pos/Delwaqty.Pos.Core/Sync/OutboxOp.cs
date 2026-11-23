using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using Delwaqty.Pos.Core.Sales;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>One queued offline operation. Serialized to the cashier_sync_push contract.</summary>
    public sealed class OutboxOp
    {
        public string OpId;
        // sync_push ops: customer | shift_open | sale | sale_void | debt_payment |
        //                stock_count | price_change | bulk_price_pct | insurance_sale
        // local ops executed by SyncEngine directly (never sent to sync_push):
        //                rpc:daily_close
        public string Type;
        public string PayloadJson;    // object matching migration 340/400's expected keys

        /// <summary>Local ops are executed by the client itself, not pushed as sync ops.</summary>
        public bool IsLocalRpc { get { return Type != null && Type.StartsWith("rpc:"); } }

        /// <summary>The RPC name for a local op ("rpc:daily_close" -> "daily_close").</summary>
        public string LocalRpcName { get { return IsLocalRpc ? Type.Substring(4) : null; } }
        public DateTimeOffset CreatedOfflineAt;
        public int Attempts;

        public OutboxOp(string type, string payloadJson)
        {
            OpId = Guid.NewGuid().ToString();
            Type = type;
            PayloadJson = payloadJson;
            CreatedOfflineAt = DateTimeOffset.UtcNow;
        }

        /// <summary>Element shape for the p_ops array: {op_id, type, created_offline_at, payload}.</summary>
        public string ToWireJson()
        {
            using (var doc = JsonDocument.Parse(PayloadJson))
            {
                return JsonSerializer.Serialize(new Dictionary<string, object>
                {
                    ["op_id"] = OpId,
                    ["type"] = Type,
                    ["created_offline_at"] = CreatedOfflineAt.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss.ffffff+00"),
                    ["payload"] = doc.RootElement,
                });
            }
        }
    }

    /// <summary>Payload builders emitting exactly the keys cashier_sync_push reads.</summary>
    public static class OutboxPayloads
    {
        private static string Json(object o) { return JsonSerializer.Serialize(o); }

        public static OutboxOp Customer(string name, string phone, string notes)
        {
            return new OutboxOp("customer", Json(new Dictionary<string, object>
            { ["name"] = name, ["phone"] = phone, ["notes"] = notes }));
        }

        /// <summary>
        /// #118: a customer created at sale time gets a stable client id (the
        /// op id itself). Deferred sales and debt payments reference that id
        /// in customer_id; the server resolves it through
        /// pos_customers.client_op_id (server-side resolution is a pending
        /// builder migration — until it lands, such ops fail visibly and stay
        /// queued instead of throwing at sale time).
        /// </summary>
        public static OutboxOp Customer(string name, string phone, string notes, string clientOpId)
        {
            return new OutboxOp("customer", Json(new Dictionary<string, object>
            { ["name"] = name, ["phone"] = phone, ["notes"] = notes }))
            { OpId = clientOpId ?? Guid.NewGuid().ToString() };
        }

        public static OutboxOp ShiftOpen(decimal openingFloat)
        {
            return new OutboxOp("shift_open", Json(new Dictionary<string, object>
            { ["opening_float"] = openingFloat }));
        }

        public static OutboxOp Sale(SaleBuilder sale)
        {
            var items = sale.Lines.Select(l => new Dictionary<string, object>
            {
                ["product_id"] = l.ProductId,
                ["drug_catalog_id"] = l.DrugCatalogId,
                ["name"] = l.Name,
                ["qty"] = l.Qty,
                ["unit_price"] = l.UnitPrice,
                ["discount_amount"] = l.DiscountAmount,
                ["total"] = l.Total,
                ["is_weight_based"] = l.IsWeightBased,
            }).ToList();
            var payments = sale.Payments.Select(p => new Dictionary<string, object>
            { ["method"] = p.Method, ["amount"] = p.Amount }).ToList();
            return new OutboxOp("sale", Json(new Dictionary<string, object>
            {
                ["items"] = items,
                ["subtotal"] = sale.Subtotal,
                ["discount_amount"] = sale.DiscountAmount,
                ["total"] = sale.Total,
                ["payments"] = payments,
                ["customer_name"] = sale.CustomerName,
                ["notes"] = sale.Notes,
                ["sale_op_id"] = null, // set by caller when linking a pre-created sale
                ["shift_id"] = sale.ShiftId,
                ["customer_id"] = sale.CustomerId,
            }));
        }

        /// <summary>
        /// Void a previously synced sale. sale_op_id is the op_id the sale was
        /// pushed with (stored as pos_sales.idempotency_key); the server resolves
        /// the sale from it. Without it the server cannot match any sale.
        /// </summary>
        public static OutboxOp SaleVoid(string saleOpId, string reason)
        {
            return new OutboxOp("sale_void", Json(new Dictionary<string, object>
            { ["sale_op_id"] = saleOpId, ["reason"] = reason }));
        }

        /// <summary>
        /// Insured sale record (PRO). company_share + patient_share must equal
        /// total within a piastre or the server rejects with INSURANCE_SHARE_MISMATCH.
        /// saleOpId optionally links the pos_sale pushed earlier (its op id).
        /// </summary>
        public static OutboxOp InsuranceSale(string companyId, string saleOpId, string memberName,
            string memberCardNo, decimal total, decimal companyShare, decimal patientShare)
        {
            return new OutboxOp("insurance_sale", Json(new Dictionary<string, object>
            {
                ["company_id"] = companyId,
                ["sale_op_id"] = saleOpId,
                ["member_name"] = memberName,
                ["member_card_no"] = memberCardNo,
                ["total"] = total,
                ["company_share"] = companyShare,
                ["patient_share"] = patientShare,
            }));
        }

        /// <summary>
        /// Local op: close the open shift with the counted drawer cash. SyncEngine
        /// executes it as cashier_daily_close when online; it is never sent to
        /// sync_push (that function has no daily-close op).
        /// </summary>
        public static OutboxOp DailyClose(string shiftId, decimal closingCash)
        {
            return new OutboxOp("rpc:daily_close", Json(new Dictionary<string, object>
            { ["shift_id"] = shiftId, ["closing_cash"] = closingCash }));
        }

        public static OutboxOp DebtPayment(string customerId, decimal amount, string note)
        {
            return new OutboxOp("debt_payment", Json(new Dictionary<string, object>
            { ["customer_id"] = customerId, ["amount"] = amount, ["note"] = note }));
        }

        public static OutboxOp StockCount(string productId, decimal counted, string note)
        {
            return new OutboxOp("stock_count", Json(new Dictionary<string, object>
            { ["product_id"] = productId, ["counted"] = counted, ["note"] = note }));
        }

        public static OutboxOp PriceChange(string productId, decimal newPrice, string source)
        {
            return new OutboxOp("price_change", Json(new Dictionary<string, object>
            { ["product_id"] = productId, ["new_price"] = newPrice, ["source"] = source ?? "manual" }));
        }

        public static OutboxOp BulkPricePct(decimal pct)
        {
            return new OutboxOp("bulk_price_pct", Json(new Dictionary<string, object>
            { ["pct"] = pct }));
        }
    }
}
