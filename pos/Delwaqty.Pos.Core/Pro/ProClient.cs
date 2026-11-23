using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Core.Pro
{
    /// <summary>
    /// PRO-tier features (migration 343, enforced 378): MoH official price
    /// application, insurance companies/statements, shortage list and reorder
    /// levels. Every function returns PRO_REQUIRED server-side when the
    /// merchant's license has no PRO flag; the app should only show these
    /// screens when device_link returned pro=true.
    /// </summary>
    public sealed class ProClient
    {
        private readonly SyncClient _client;
        private readonly string _merchantId;

        public ProClient(SyncClient client, string merchantId)
        {
            _client = client;
            _merchantId = merchantId;
        }

        /// <summary>Apply MoH official prices to the store's matched products.</summary>
        public Task<string> ApplyMohPricesAsync()
        {
            return _client.RpcAsync("cashier_apply_moh_prices",
                "{\"p_merchant_id\":" + J(_merchantId) + "}");
        }

        /// <summary>Products at or below their reorder level (النواقص).</summary>
        public Task<string> ShortageListAsync(int defaultLevel)
        {
            return _client.RpcAsync("cashier_shortage_list",
                "{\"p_merchant_id\":" + J(_merchantId) + ",\"p_default_level\":" + defaultLevel + "}");
        }

        public Task<string> SetReorderLevelAsync(string productId, int level)
        {
            return _client.RpcAsync("cashier_set_reorder_level",
                "{\"p_merchant_id\":" + J(_merchantId) +
                ",\"p_product_id\":" + J(productId) + ",\"p_level\":" + level + "}");
        }

        /// <summary>Insurance statement for a company over a period (كشف حساب تأمين).</summary>
        public Task<string> InsuranceStatementAsync(string companyId, System.DateTimeOffset from, System.DateTimeOffset to)
        {
            return _client.RpcAsync("pos_insurance_statement",
                "{\"p_merchant_id\":" + J(_merchantId) +
                ",\"p_company_id\":" + J(companyId) +
                ",\"p_from\":" + J(from.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss+00")) +
                ",\"p_to\":" + J(to.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss+00")) + "}");
        }

        // Insurance companies: plain REST CRUD (RLS gates to PRO merchants).

        public Task<string> InsuranceCompaniesAsync()
        {
            return _client.RestGetAsync("pos_insurance_companies?select=*&merchant_id=eq." +
                _merchantId + "&order=name.asc");
        }

        public Task<string> InsuranceCompanyCreateAsync(string name, string phone, string notes)
        {
            var body = JsonSerializer.Serialize(new Dictionary<string, object>
            {
                ["merchant_id"] = _merchantId,
                ["name"] = name,
                ["phone"] = phone,
                ["notes"] = notes,
            });
            return _client.RestWriteAsync("POST", "pos_insurance_companies", body, "return=representation");
        }

        private static string J(string s)
        {
            return s == null ? "null" : JsonSerializer.Serialize(s);
        }
    }
}
