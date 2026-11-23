using System;
using System.IO;
using System.Linq;
using Delwaqty.Pos.Core.Pharmacy;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>
    /// #120: expired batches are ineligible, shortfalls are reported, batch
    /// movements are recorded per sale and restored on void, and the whole
    /// sale commit is one transaction.
    /// </summary>
    public class BatchAndLocalDbTests : IDisposable
    {
        private readonly string _dir = Path.Combine(Path.GetTempPath(), "posdb-" + Guid.NewGuid());
        public BatchAndLocalDbTests() { Directory.CreateDirectory(_dir); }
        public void Dispose() { Directory.Delete(_dir, true); }

        private string DbPath { get { return Path.Combine(_dir, "pos.db"); } }

        private static SaleBuilder MakeSale(string key, decimal qty)
        {
            var s = new SaleBuilder();
            s.AddLine(new SaleLine { Name = "اوجمنتين", ProductId = key, Qty = qty, UnitPrice = 50 });
            s.AddPayment("cash", 50 * qty);
            s.Close();
            return s;
        }

        [Fact]
        public void Expired_Batches_Are_Ineligible_For_Fefo()
        {
            using (var db = new PosLocalDb(DbPath))
            {
                var today = DateTime.Today;
                db.Batches.AddBatch("item-1", "اوجمنتين", 5, today.AddDays(-1), "B-expired");
                db.Batches.AddBatch("item-1", "اوجمنتين", 3, today.AddDays(30), "B-good");

                var alloc = db.Batches.AllocateFefo("item-1", 4);
                Assert.Equal(3, alloc.Allocated);  // only the sellable batch
                Assert.Equal(1, alloc.Missing);    // shortfall is reported
                Assert.False(alloc.Covered);

                // The expired stock is visible for write-off, not for sale.
                Assert.Single(db.Batches.ExpiredFor("item-1"));
                Assert.Single(db.Batches.BatchesFor("item-1"));
            }
        }

        [Fact]
        public void Dispense_Records_Allocations_And_Void_Restores_Exactly()
        {
            using (var db = new PosLocalDb(DbPath))
            {
                var today = DateTime.Today;
                var b1 = db.Batches.AddBatch("item-1", "اوجمنتين", 3, today.AddDays(10), "B1");
                var b2 = db.Batches.AddBatch("item-1", "اوجمنتين", 5, today.AddDays(40), "B2");

                var plan = db.Batches.Dispense("item-1", 4, "sale-1");
                Assert.True(plan.Covered);
                var allocs = db.Batches.AllocationsFor("sale-1");
                Assert.Equal(2, allocs.Count);
                Assert.Equal((b1, 3m, false), allocs[0]);
                Assert.Equal((b2, 1m, false), allocs[1]);
                Assert.Equal(4, db.Batches.TrackedQty("item-1"));

                var restored = db.Batches.RestoreForVoid("sale-1");
                Assert.Equal(4, restored);
                Assert.Equal(8, db.Batches.TrackedQty("item-1"));
                Assert.Equal(3, db.Batches.BatchesFor("item-1").Single(b => b.Id == b1).QtyOnHand);
                // Idempotent: a second restore does nothing.
                Assert.Equal(0, db.Batches.RestoreForVoid("sale-1"));
                Assert.All(db.Batches.AllocationsFor("sale-1"), a => Assert.True(a.Voided));
            }
        }

        [Fact]
        public void CommitSale_Is_Atomic_With_Dispense_And_Journal()
        {
            using (var db = new PosLocalDb(DbPath))
            {
                db.Batches.AddBatch("item-1", "اوجمنتين", 10, DateTime.Today.AddDays(30), "B1");
                var sale = MakeSale("item-1", 4);
                var op = OutboxPayloads.Sale(sale);

                db.CommitSale(op, sale, "shift-local-1", dispenseBatches: true);

                Assert.Equal(1, db.Outbox.PendingCount());
                Assert.Single(db.Sales.SalesForShift("shift-local-1"));
                Assert.Equal(6, db.Batches.TrackedQty("item-1"));
                Assert.Single(db.Batches.AllocationsFor(op.OpId));
                Assert.Equal(4, db.Batches.AllocationsFor(op.OpId).Sum(a => a.Qty));

                // And the void unwinds all three in one transaction.
                db.VoidSale(OutboxPayloads.SaleVoid(op.OpId, "خطأ"), op.OpId);
                Assert.Equal(2, db.Outbox.PendingCount()); // sale + void ops
                Assert.Equal("voided", db.Sales.Recent(1)[0].Status);
                Assert.Equal(10, db.Batches.TrackedQty("item-1"));
            }
        }

        [Fact]
        public void Transaction_Rolls_Back_On_Failure()
        {
            using (var db = new PosLocalDb(DbPath))
            {
                db.Batches.AddBatch("item-1", "اوجمنتين", 10, DateTime.Today.AddDays(30), "B1");
                var sale = MakeSale("item-1", 4);
                var op = OutboxPayloads.Sale(sale);
                Assert.Throws<InvalidOperationException>(() => db.Tx(() =>
                {
                    db.Outbox.Enqueue(op);
                    db.Sales.Add(new LocalSalesLog.OutboxOpRef(op.OpId), sale, "s-1");
                    db.Batches.Dispense("item-1", 4, op.OpId);
                    throw new InvalidOperationException("simulated crash mid-commit");
                }));
                // Nothing survived: no op, no journal row, no batch movement.
                Assert.Equal(0, db.Outbox.PendingCount());
                Assert.Empty(db.Sales.Recent(5));
                Assert.Equal(10, db.Batches.TrackedQty("item-1"));
                Assert.Empty(db.Batches.AllocationsFor(op.OpId));
            }
        }

        [Fact]
        public void CommitSale_Blocks_Atomicallly_On_Tracked_Shortfall()
        {
            // #120 follow-up: tracked stock that cannot cover the line
            // (including all-expired batches) aborts the WHOLE sale — no
            // outbox op, no journal row, no partial batch movement.
            using (var db = new PosLocalDb(DbPath))
            {
                db.Batches.AddBatch("item-1", "اوجمنتين", 3, DateTime.Today.AddDays(30), "B1");
                db.Batches.AddBatch("item-1", "اوجمنتين", 5, DateTime.Today.AddDays(-2), "B0"); // expired
                var sale = MakeSale("item-1", 4); // sellable is only 3
                var op = OutboxPayloads.Sale(sale);

                var ex = Assert.Throws<InvalidOperationException>(() =>
                    db.CommitSale(op, sale, "shift-1", dispenseBatches: true));
                Assert.StartsWith("INSUFFICIENT_TRACKED_STOCK", ex.Message);
                Assert.Equal(0, db.Outbox.PendingCount());
                Assert.Empty(db.Sales.Recent(5));
                Assert.Equal(8, db.Batches.TrackedQty("item-1")); // untouched
                Assert.Empty(db.Batches.AllocationsFor(op.OpId));
            }
        }

        [Fact]
        public void CommitSale_Untracked_Quick_Line_Sells_Without_Dispensing()
        {
            // The explicit untracked policy: an item with NO batches ever
            // recorded sells freely and records no allocation rows.
            using (var db = new PosLocalDb(DbPath))
            {
                var sale = MakeSale("never-tracked", 2);
                var op = OutboxPayloads.Sale(sale);
                db.CommitSale(op, sale, "shift-1", dispenseBatches: true);
                Assert.Equal(1, db.Outbox.PendingCount());
                Assert.Single(db.Sales.Recent(5));
                Assert.Empty(db.Batches.AllocationsFor(op.OpId));
            }
        }

        [Fact]
        public void Corrupt_Legacy_Db_Sets_Repair_State_And_Keeps_The_File()
        {
            // #120 migration follow-up: an unreadable legacy file must surface
            // a repair state instead of silently running on an empty pos.db.
            File.WriteAllText(Path.Combine(_dir, "outbox.db"), "definitely not sqlite");
            using (var db = new PosLocalDb(DbPath))
            {
                Assert.NotNull(db.RepairState);
                Assert.Contains("outbox.db", db.RepairState);
            }
            Assert.True(File.Exists(Path.Combine(_dir, "outbox.db"))); // kept for support
        }

        [Fact]
        public void Legacy_Separate_Dbs_Are_Imported_Once()
        {
            // Pre-pos.db layout: three separate files.
            using (var legacy = new OutboxStore(Path.Combine(_dir, "outbox.db")))
                legacy.Enqueue(OutboxPayloads.Customer("احمد", "010", null));
            using (var legacy = new LocalSalesLog(Path.Combine(_dir, "sales.db")))
            {
                var sale = MakeSale(null, 1);
                legacy.Add(new LocalSalesLog.OutboxOpRef("op-legacy"), sale, "shift-1");
            }
            using (var legacy = new BatchStore(Path.Combine(_dir, "batches.db")))
                legacy.AddBatch("item-1", "اوجمنتين", 7, DateTime.Today.AddDays(30), "B1");

            using (var db = new PosLocalDb(DbPath))
            {
                Assert.Null(db.RepairState);
                Assert.Equal(1, db.Outbox.PendingCount());
                Assert.Single(db.Sales.Recent(5));
                Assert.Equal(7, db.Batches.TrackedQty("item-1"));
                // The row-count assertion ran: one row per legacy table.
                Assert.Equal(1, db.ImportedCounts["outbox"]);
                Assert.Equal(1, db.ImportedCounts["local_sales"]);
                Assert.Equal(1, db.ImportedCounts["batches"]);
            }
            // Legacy files moved aside; a second open imports nothing again.
            Assert.True(File.Exists(Path.Combine(_dir, "outbox.db.migrated")));
            using (var db = new PosLocalDb(DbPath))
                Assert.Equal(1, db.Outbox.PendingCount());
        }
    }
}
