using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Core.Network
{
    /// <summary>
    /// Inter-pharmacy shortage exchange (migration 341, hardened 348).
    /// Tables are read-only over REST; every change goes through the RPCs.
    /// Settlement is two-phase: one side proposes (settle), the OTHER side
    /// confirms (settle_confirm) before the ledger entry is written.
    /// </summary>
    public sealed class PharmacyNetworkClient
    {
        private readonly SyncClient _client;
        private readonly string _merchantId;

        public PharmacyNetworkClient(SyncClient client, string merchantId)
        {
            _client = client;
            _merchantId = merchantId;
        }

        // ---- RPC wrappers (changes) ----

        public Task<string> DirectoryAsync()
        {
            return _client.RpcAsync("pharmacy_directory",
                "{\"p_merchant_id\":" + J(_merchantId) + "}");
        }

        public Task<string> LinkCreateAsync(string otherMerchantId)
        {
            return _client.RpcAsync("pharmacy_link_create",
                "{\"p_merchant_id\":" + J(_merchantId) +
                ",\"p_other_merchant_id\":" + J(otherMerchantId) + "}");
        }

        /// <summary>Request a missing item from a linked pharmacy (migration 341 signature).</summary>
        public Task<string> TransferRequestAsync(string linkId, string itemName, decimal qty,
            string drugCatalogId, string note)
        {
            return _client.RpcAsync("pharmacy_transfer_request",
                "{\"p_link_id\":" + J(linkId) +
                ",\"p_item_name\":" + J(itemName) +
                ",\"p_qty\":" + qty.ToString(System.Globalization.CultureInfo.InvariantCulture) +
                (drugCatalogId != null ? ",\"p_drug_catalog_id\":" + J(drugCatalogId) : "") +
                (note != null ? ",\"p_note\":" + J(note) : "") + "}");
        }

        public Task<string> TransferRespondAsync(string transferId, bool accept, decimal? cashValue)
        {
            return _client.RpcAsync("pharmacy_transfer_respond",
                "{\"p_transfer_id\":" + J(transferId) +
                ",\"p_accept\":" + (accept ? "true" : "false") +
                (cashValue.HasValue ? ",\"p_cash_value\":" + cashValue.Value.ToString(System.Globalization.CultureInfo.InvariantCulture) : "") + "}");
        }

        public Task<string> TransferHandoverAsync(string transferId, decimal? cashValue)
        {
            return _client.RpcAsync("pharmacy_transfer_handover",
                "{\"p_transfer_id\":" + J(transferId) +
                (cashValue.HasValue ? ",\"p_cash_value\":" + cashValue.Value.ToString(System.Globalization.CultureInfo.InvariantCulture) : "") + "}");
        }

        /// <summary>
        /// Propose settlement (migration 348): mode 'swap' (بدل in kind) or 'cash'.
        /// Status becomes settlement_pending; the OTHER side must confirm before
        /// the ledger entry is written.
        /// </summary>
        public Task<string> TransferSettleAsync(string transferId, string mode, decimal? cashAmount, string swapDesc)
        {
            return _client.RpcAsync("pharmacy_transfer_settle",
                "{\"p_transfer_id\":" + J(transferId) + ",\"p_mode\":" + J(mode) +
                (cashAmount.HasValue ? ",\"p_cash_amount\":" + cashAmount.Value.ToString(System.Globalization.CultureInfo.InvariantCulture) : "") +
                (swapDesc != null ? ",\"p_swap_desc\":" + J(swapDesc) : "") + "}");
        }

        /// <summary>Confirm or reject a settlement proposed by the other side.</summary>
        public Task<string> TransferSettleConfirmAsync(string transferId, bool accept)
        {
            return _client.RpcAsync("pharmacy_transfer_settle_confirm",
                "{\"p_transfer_id\":" + J(transferId) + ",\"p_accept\":" + (accept ? "true" : "false") + "}");
        }

        public Task<string> MessageSendAsync(string linkId, string body, string transferId)
        {
            return _client.RpcAsync("pharmacy_message_send",
                "{\"p_link_id\":" + J(linkId) + ",\"p_body\":" + J(body) +
                (transferId != null ? ",\"p_transfer_id\":" + J(transferId) : "") + "}");
        }

        // ---- REST reads (read-only tables) ----

        public Task<string> LinksAsync()
        {
            return _client.RestGetAsync("pharmacy_links?select=*&or=(pharmacy_a.eq." +
                _merchantId + ",pharmacy_b.eq." + _merchantId + ")");
        }

        public Task<string> TransfersAsync()
        {
            return _client.RestGetAsync("pharmacy_transfer_requests?select=*&order=created_at.desc&limit=100");
        }

        public Task<string> LedgerAsync(string linkId)
        {
            return _client.RestGetAsync("pharmacy_transfer_ledger?select=*&link_id=eq." + linkId +
                "&order=created_at.desc&limit=100");
        }

        public Task<string> MessagesAsync(string linkId)
        {
            return _client.RestGetAsync("pharmacy_messages?select=*&link_id=eq." + linkId +
                "&order=created_at.asc&limit=200");
        }

        private static string J(string s)
        {
            return s == null ? "null" : JsonSerializer.Serialize(s);
        }
    }
}
