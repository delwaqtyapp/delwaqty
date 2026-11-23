using System;
using System.IO;
using Delwaqty.Pos.Core.Licensing;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>
    /// Upgrade completeness: unverifiable pre-DP1 flat-layout data with an
    /// unsynced queue must NEVER be abandoned under a fresh empty scope —
    /// the app enters a visible repair state (no activation, no selling),
    /// every file untouched, until support runs a verified migration.
    /// </summary>
    public class LegacyRepairTests : IDisposable
    {
        private readonly string _dir = Path.Combine(Path.GetTempPath(), "repair-" + Guid.NewGuid());
        public LegacyRepairTests() { Directory.CreateDirectory(_dir); }
        public void Dispose() { Directory.Delete(_dir, true); }

        private void WriteFlatOutboxWithPendingOp()
        {
            using (var store = new OutboxStore(Path.Combine(_dir, "outbox.db")))
                store.Enqueue(OutboxPayloads.Customer("احمد", "010", null));
        }

        /// <summary>A v1 seal whose payload HMAC uses a key this install does NOT have.</summary>
        private void WriteUnverifiableLegacySeal(string merchantId)
        {
            var foreignKey = LocalLicenseSeal.NewDeviceKey();
            var payload = Guid.NewGuid() + "|" + merchantId + "|core_annual|lifetime|dev-old|" +
                DateTimeOffset.UtcNow.ToString("o");
            File.WriteAllText(Path.Combine(_dir, "license.seal"),
                "{\"Payload\":" + System.Text.Json.JsonSerializer.Serialize(payload) +
                ",\"Seal\":\"" + LocalLicenseSeal.Seal(payload, foreignKey) +
                "\",\"StateJson\":\"{}\"}");
        }

        [Fact]
        public void Clean_Root_Needs_No_Repair()
        {
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.Null(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Pending_Flat_Outbox_Needs_Repair()
        {
            WriteFlatOutboxWithPendingOp();
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.NotNull(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Unreadable_Flat_Outbox_Fails_Closed()
        {
            File.WriteAllText(Path.Combine(_dir, "outbox.db"), "not sqlite at all");
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.NotNull(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Fully_Synced_Flat_Outbox_Needs_No_Repair()
        {
            using (var store = new OutboxStore(Path.Combine(_dir, "outbox.db")))
            {
                var op = OutboxPayloads.Customer("احمد", "010", null);
                store.Enqueue(op);
                store.MarkSynced(op.OpId);
            }
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.Null(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Flat_Sales_History_Needs_Repair()
        {
            using (var log = new LocalSalesLog(Path.Combine(_dir, "sales.db")))
            {
                var sale = new SaleBuilder { ShiftId = "s-1" };
                sale.AddLine(new SaleLine { Name = "بنادول", Qty = 1, UnitPrice = 10 });
                sale.AddPayment("cash", 10);
                sale.Close();
                log.Add(new LocalSalesLog.OutboxOpRef("op-1"), sale, "s-1");
            }
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.NotNull(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Verifiable_Legacy_Seal_Migrates_Instead_Of_Repairing()
        {
            // DP1-era install (key intact): the payload verifies, the normal
            // migration path runs on re-activation, no repair state.
            WriteFlatOutboxWithPendingOp();
            var svc = new ActivationService(_dir, "Pharmacy");
            var payload = Guid.NewGuid() + "|m-1|core_annual|lifetime|" + svc.LocalDeviceId + "|" +
                DateTimeOffset.UtcNow.ToString("o");
            File.WriteAllText(Path.Combine(_dir, "license.seal"),
                "{\"Payload\":" + System.Text.Json.JsonSerializer.Serialize(payload) +
                ",\"Seal\":\"" + LocalLicenseSeal.Seal(payload, svc.DeviceKey) +
                "\",\"StateJson\":\"{}\"}");
            Assert.Null(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Flat_Stock_Without_Pending_Sale_Still_Needs_Repair()
        {
            // Reviewer gap: a pre-DP1 pharmacy with stock batches but no
            // pending sale and no sales.db must NOT pass clean — the new
            // scope would silently omit the old stock.
            using (var batches = new Pharmacy.BatchStore(Path.Combine(_dir, "batches.db")))
                batches.AddBatch("item-1", "اوجمنتين", 7, DateTime.Today.AddDays(30), "B1");
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.NotNull(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Root_PosDb_History_Without_Pending_Ops_Needs_Repair()
        {
            // pos.db with sales history or stock but an empty queue is still
            // financial history that must not vanish.
            using (var db = new PosLocalDb(Path.Combine(_dir, "pos.db"), importLegacy: false))
            {
                var sale = new SaleBuilder { ShiftId = "s-1" };
                sale.AddLine(new SaleLine { Name = "بنادول", Qty = 1, UnitPrice = 10 });
                sale.AddPayment("cash", 10);
                sale.Close();
                var op = OutboxPayloads.Sale(sale);
                db.CommitSale(op, sale, "s-1", dispenseBatches: false);
                db.Outbox.MarkSynced(op.OpId); // fully synced — but history exists
            }
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.NotNull(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Nonempty_Catalog_Or_Shift_State_Needs_Repair()
        {
            using (var db = new Microsoft.Data.Sqlite.SqliteConnection(
                "Data Source=" + Path.Combine(_dir, "catalog.db")))
            {
                db.Open();
                using (var cmd = db.CreateCommand())
                {
                    cmd.CommandText = "CREATE TABLE catalog (id TEXT PRIMARY KEY, name TEXT);" +
                        "INSERT INTO catalog VALUES ('d-1','بنادول');";
                    cmd.ExecuteNonQuery();
                }
            }
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.NotNull(svc.LegacyRepairReason(null));

            File.Delete(Path.Combine(_dir, "catalog.db"));
            File.WriteAllText(Path.Combine(_dir, "shift.json"), "{\"opId\":\"x\",\"openingFloat\":100}");
            Assert.NotNull(svc.LegacyRepairReason(null));
        }

        [Fact]
        public void Detector_Never_Modifies_The_Files()
        {
            // The repair promise "no file touched" must be literally true:
            // the detector opens every db READ-ONLY (reviewer gap: the store
            // constructors CREATE tables).
            WriteFlatOutboxWithPendingOp();
            var path = Path.Combine(_dir, "outbox.db");
            var before = File.ReadAllBytes(path);
            var svc = new ActivationService(_dir, "Pharmacy");
            Assert.NotNull(svc.LegacyRepairReason(null));
            Assert.Equal(before, File.ReadAllBytes(path));
        }

        [Fact]
        public async System.Threading.Tasks.Task Verified_Other_Merchant_Blocks_The_Switch()
        {
            // Reviewer gap: a VERIFIED legacy owner who is not the newly
            // activated merchant used to skip both migration and repair,
            // hiding the old root data. Now the switch blocks pending
            // verified archival/migration.
            WriteFlatOutboxWithPendingOp();
            var svc = new ActivationService(_dir, "Pharmacy");
            var payload = Guid.NewGuid() + "|m-OLD|core_annual|lifetime|" + svc.LocalDeviceId + "|" +
                DateTimeOffset.UtcNow.ToString("o");
            File.WriteAllText(Path.Combine(_dir, "license.seal"),
                "{\"Payload\":" + System.Text.Json.JsonSerializer.Serialize(payload) +
                ",\"Seal\":\"" + LocalLicenseSeal.Seal(payload, svc.DeviceKey) +
                "\",\"StateJson\":\"{}\"}");

            var stub = new StubHandler()
                .Ok("{\"access_token\":\"at\",\"refresh_token\":\"rt\",\"expires_in\":3600,\"user\":{\"id\":\"u\"}}")
                .Ok("{\"ok\":true,\"plan\":\"core_annual\",\"pro\":true,\"status\":\"active\"," +
                    "\"expires_at\":\"" + DateTimeOffset.UtcNow.AddMonths(6).ToString("yyyy-MM-dd HH:mm:ss+00") + "\"," +
                    "\"merchant\":{\"id\":\"m-NEW\",\"name\":\"محل جديد\",\"type\":\"grocery\"}}");
            var http = new System.Net.Http.HttpClient(stub);
            var auth = new Auth.AuthClient("https://x.supabase.co", "anon", http);
            var sync = new SyncClient("https://x.supabase.co", "anon", http);
            var key = "DLWQ1." + LicenseKey.Base64UrlEncode(
                System.Text.Encoding.UTF8.GetBytes(Guid.NewGuid() + "|m-NEW|core_annual|lifetime")) +
                "." + new string('a', 64);

            var res = await svc.ActivateAsync(auth, sync, "m@example.com", "pw", key, svc.LocalDeviceId);

            Assert.False(res.Ok);
            Assert.Equal("LEGACY_DATA_NEEDS_REPAIR", res.Reason);
            Assert.Contains("m-OLD", res.Error);
            using (var store = new OutboxStore(Path.Combine(_dir, "outbox.db")))
                Assert.Equal(1, store.PendingCount()); // untouched
            Assert.False(Directory.Exists(Path.Combine(_dir, "merchants")));
        }

        [Fact]
        public async System.Threading.Tasks.Task Activation_Is_Refused_And_Data_Untouched_When_Unverifiable()
        {
            // The reported bug: key regenerated -> legacy merchant unverifiable
            // -> activation started an empty scope and the old queue vanished.
            // Now: activation is REFUSED with LEGACY_DATA_NEEDS_REPAIR and
            // every byte stays where it was.
            WriteFlatOutboxWithPendingOp();
            WriteUnverifiableLegacySeal("m-1");

            var svc = new ActivationService(_dir, "Pharmacy");
            var stub = new StubHandler()
                .Ok("{\"access_token\":\"at\",\"refresh_token\":\"rt\",\"expires_in\":3600,\"user\":{\"id\":\"u\"}}")
                .Ok("{\"ok\":true,\"plan\":\"core_annual\",\"pro\":true,\"status\":\"active\"," +
                    "\"expires_at\":\"" + DateTimeOffset.UtcNow.AddMonths(6).ToString("yyyy-MM-dd HH:mm:ss+00") + "\"," +
                    "\"merchant\":{\"id\":\"m-1\",\"name\":\"صيدلية الشفاء\",\"type\":\"pharmacy\"}}");
            var http = new System.Net.Http.HttpClient(stub);
            var auth = new Auth.AuthClient("https://x.supabase.co", "anon", http);
            var sync = new SyncClient("https://x.supabase.co", "anon", http);
            var key = "DLWQ1." + LicenseKey.Base64UrlEncode(
                System.Text.Encoding.UTF8.GetBytes(Guid.NewGuid() + "|m-1|core_annual|lifetime")) +
                "." + new string('a', 64);

            var res = await svc.ActivateAsync(auth, sync, "m@example.com", "pw", key, svc.LocalDeviceId);

            Assert.False(res.Ok);
            Assert.Equal("LEGACY_DATA_NEEDS_REPAIR", res.Reason);
            // Data intact: the pending op still sits in the root outbox and
            // no empty merchant scope was created over it.
            Assert.True(File.Exists(Path.Combine(_dir, "outbox.db")));
            using (var store = new OutboxStore(Path.Combine(_dir, "outbox.db")))
                Assert.Equal(1, store.PendingCount());
            Assert.False(Directory.Exists(Path.Combine(_dir, "merchants")));
            Assert.Null(svc.CurrentScopeDir);
        }
    }
}
