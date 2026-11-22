using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>Thin Supabase REST client for the cashier RPCs (migrations 340/341).</summary>
    public sealed class SyncClient
    {
        private readonly HttpClient _http;
        private readonly string _baseUrl;
        private readonly string _anonKey;

        public string AccessToken;

        public SyncClient(string baseUrl, string anonKey, HttpClient http = null)
        {
            _baseUrl = baseUrl.TrimEnd('/');
            _anonKey = anonKey;
            _http = http ?? new HttpClient();
        }

        public async Task<string> RpcAsync(string fn, string bodyJson)
        {
            using (var req = new HttpRequestMessage(HttpMethod.Post, _baseUrl + "/rest/v1/rpc/" + fn))
            {
                req.Headers.Add("apikey", _anonKey);
                if (AccessToken != null)
                    req.Headers.Authorization =
                        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", AccessToken);
                req.Content = new StringContent(bodyJson, Encoding.UTF8, "application/json");
                using (var res = await _http.SendAsync(req).ConfigureAwait(false))
                {
                    var text = await res.Content.ReadAsStringAsync().ConfigureAwait(false);
                    if (!res.IsSuccessStatusCode)
                        throw new InvalidOperationException(fn + " failed: " + (int)res.StatusCode + " " + text);
                    return text;
                }
            }
        }

        public Task<string> ValidateLicense(string licenseKey, string deviceId)
        {
            return RpcAsync("cashier_license_validate",
                "{\"p_license_key\":" + JsonString(licenseKey) +
                ",\"p_device_id\":" + JsonString(deviceId) + "}");
        }

        /// <summary>
        /// Activation + platform linking in one call (migration 343): binds the
        /// device to the license on first contact and returns the merchant
        /// profile/config the app needs to set itself up.
        /// </summary>
        public Task<string> DeviceLink(string licenseKey, string deviceId)
        {
            return RpcAsync("cashier_device_link",
                "{\"p_license_key\":" + JsonString(licenseKey) +
                ",\"p_device_id\":" + JsonString(deviceId) + "}");
        }

        public Task<string> PushOps(string merchantId, string opsArrayJson)
        {
            return RpcAsync("cashier_sync_push",
                "{\"p_merchant_id\":" + JsonString(merchantId) + ",\"p_ops\":" + opsArrayJson + "}");
        }

        public Task<string> Pull(string merchantId, string sinceIso)
        {
            var body = "{\"p_merchant_id\":" + JsonString(merchantId);
            if (sinceIso != null) body += ",\"p_since\":" + JsonString(sinceIso);
            return RpcAsync("cashier_sync_pull", body + "}");
        }

        public Task<string> DailyClose(string merchantId, string shiftId, decimal closingCash)
        {
            return RpcAsync("cashier_daily_close",
                "{\"p_merchant_id\":" + JsonString(merchantId) +
                ",\"p_shift_id\":" + JsonString(shiftId) +
                ",\"p_closing_cash\":" + closingCash.ToString(System.Globalization.CultureInfo.InvariantCulture) + "}");
        }

        public Task<string> CatalogSearchOnline(string query, int limit)
        {
            return RpcAsync("drug_catalog_search",
                "{\"p_query\":" + JsonString(query) + ",\"p_limit\":" + limit + "}");
        }

        private static string JsonString(string s)
        {
            return s == null ? "null" : System.Text.Json.JsonSerializer.Serialize(s);
        }
    }
}
