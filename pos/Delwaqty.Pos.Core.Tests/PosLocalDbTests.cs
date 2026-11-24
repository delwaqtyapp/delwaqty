using System;
using System.IO;
using System.Linq;
using Delwaqty.Pos.Core.Sales;
using Delwaqty.Pos.Core.Sync;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    /// <summary>
    /// #120: the outbox op and the sales journal row commit atomically, and
    /// the legacy separate-db import is count-asserted and idempotent.
    /// </summary>
    public class PosLocalDbTests : IDisposable
    {
        private readonly string _dir = Path.Combine(Path.GetTempPath(), "posdb-" + Guid.NewGuid());
        public PosLocalDbTests() { Directory.CreateDirectory(_dir); }
        public void Dispose() { Microsoft.Data.Sqlite.SqliteConnection.ClearAllPools(); Directory.Delete(_dir, true); }

        private string DbPath { get { return Path.Combine(_dir, "pos.db"); } }

        private static SaleBuilder MakeSale(string productId, decimal qty)
        {
            var sale = new SaleBuilder();
            sale.AddLine(new SaleLine { ProductId = productId, Name = "زيت", Qty = qty, UnitPrice = 10 });
            sale.AddPayment("cash", qty * 10);
            sale.Close();
            return sale;
        }

        [Fact]
        public void CommitSale_Writes_Op_And_Journal_Atomically()
        {
            using (var db = new PosLocalDb(DbPath))
            {
                var sale = MakeSale("item-1", 2);
                var op = OutboxPayloads.Sale(sale);
                db.CommitSale(op, sale, "shift-1");
                Assert.Equal(1, db.Outbox.PendingCount());
                var rows = db.Sales.Recent(5);
                Assert.Single(rows);
                Assert.Equal(op.OpId, rows[0].OpId);
                Assert.Equal(20, rows[0].Total);
            }
        }

        [Fact]
        public void VoidSale_Enqueues_Op_And_Marks_Journal_Atomically()
        {
            using (var db = new PosLocalDb(DbPath))
            {
                var sale = MakeSale("item-1", 1);
                var op = OutboxPayloads.Sale(sale);
                db.CommitSale(op, sale, "shift-1");
                db.VoidSale(OutboxPayloads.SaleVoid(op.OpId, "خطأ"), op.OpId);
                Assert.Equal(2, db.Outbox.PendingCount());
                Assert.Equal("voided", db.Sales.Recent(5).Single().Status);
            }
        }

        [Fact]
        public void Commit_Rolls_Back_Outbox_And_Journal_On_Failure()
        {
            // Failure-injected rollback: if anything inside the commit
            // transaction throws after the first write, NEITHER the outbox
            // op nor the journal row may survive.
            using (var db = new PosLocalDb(DbPath))
            {
                var sale = MakeSale("item-1", 2);
                var op = OutboxPayloads.Sale(sale);
                Assert.Throws<InvalidOperationException>(() => db.Tx(() =>
                {
                    db.Outbox.Enqueue(op);
                    db.Sales.Add(new LocalSalesLog.OutboxOpRef(op.OpId), sale, "shift-1");
                    throw new InvalidOperationException("simulated crash mid-commit");
                }));
                Assert.Equal(0, db.Outbox.PendingCount());
                Assert.Empty(db.Sales.Recent(5));
            }
        }

        [Fact]
        public void Void_Rolls_Back_On_Second_Write_Failure()
        {
            // A void is two writes (void op + journal mark). A failure
            // between them must leave the sale untouched: no extra outbox
            // op, no voided status.
            using (var db = new PosLocalDb(DbPath))
            {
                var sale = MakeSale("item-1", 1);
                var op = OutboxPayloads.Sale(sale);
                db.CommitSale(op, sale, "shift-1");
                Assert.Equal(1, db.Outbox.PendingCount());

                var voidOp = OutboxPayloads.SaleVoid(op.OpId, "خطأ");
                Assert.Throws<InvalidOperationException>(() => db.Tx(() =>
                {
                    db.Outbox.Enqueue(voidOp);
                    throw new InvalidOperationException("simulated crash before journal mark");
                }));
                Assert.Equal(1, db.Outbox.PendingCount()); // only the original sale op
                Assert.Equal("completed", db.Sales.Recent(5).Single().Status);
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
            // Pre-pos.db layout: separate outbox and sales files.
            using (var legacy = new OutboxStore(Path.Combine(_dir, "outbox.db")))
                legacy.Enqueue(OutboxPayloads.Customer("احمد", "010", null));
            using (var legacy = new LocalSalesLog(Path.Combine(_dir, "sales.db")))
            {
                var sale = MakeSale(null, 1);
                legacy.Add(new LocalSalesLog.OutboxOpRef("op-legacy"), sale, "shift-1");
            }

            using (var db = new PosLocalDb(DbPath))
            {
                Assert.Null(db.RepairState);
                Assert.Equal(1, db.Outbox.PendingCount());
                Assert.Single(db.Sales.Recent(5));
                // The row-count assertion ran: one row per legacy table.
                Assert.Equal(1, db.ImportedCounts["outbox"]);
                Assert.Equal(1, db.ImportedCounts["local_sales"]);
            }
            // Legacy files moved aside; a second open imports nothing again.
            Assert.True(File.Exists(Path.Combine(_dir, "outbox.db.migrated")));
            using (var db = new PosLocalDb(DbPath))
                Assert.Equal(1, db.Outbox.PendingCount());
        }
    }
}
