using System;
using System.IO;
using Delwaqty.Pos.Core.Pharmacy;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class ControlledSubstancesTests
    {
        [Fact]
        public void Flags_By_Active_Ingredient()
        {
            Assert.True(ControlledSubstances.IsControlled("Tramadol HCl"));
            Assert.True(ControlledSubstances.IsControlled("ALPRAZOLAM 0.5mg"));
            Assert.True(ControlledSubstances.IsControlled("Pregabalin"));
        }

        [Fact]
        public void Flags_By_Product_Name_Containing_The_Ingredient()
        {
            Assert.True(ControlledSubstances.IsControlled("Ultracet (Tramadol + Paracetamol)"));
        }

        [Fact]
        public void Ordinary_Items_Are_Not_Flagged()
        {
            Assert.False(ControlledSubstances.IsControlled("Paracetamol 500mg"));
            Assert.False(ControlledSubstances.IsControlled("كونتافيفير ن"));
            Assert.False(ControlledSubstances.IsControlled(null));
            Assert.False(ControlledSubstances.IsControlled(""));
        }

        [Fact]
        public void Combination_Names_Are_Split_On_Every_Separator()
        {
            // #120: combination products without spaces around the separator.
            Assert.True(ControlledSubstances.IsControlled("tramadol+paracetamol"));
            Assert.True(ControlledSubstances.IsControlled("Tramadol/Paracetamol"));
            Assert.True(ControlledSubstances.IsControlled("PARACETAMOL+TRAMADOL 325/37.5"));
            Assert.True(ControlledSubstances.IsControlled("Codeine,Phosphate"));
        }

        [Fact]
        public void Null_Or_Empty_Ingredient_Falls_Back_To_The_Display_Name()
        {
            // #120: null and whitespace ingredient both mean "check by name".
            Assert.True(ControlledSubstances.ShouldWarn(null, "Ultracet Tramadol"));
            Assert.True(ControlledSubstances.ShouldWarn("", "Ultracet Tramadol"));
            Assert.True(ControlledSubstances.ShouldWarn("   ", "Ultracet Tramadol"));
            Assert.True(ControlledSubstances.ShouldWarn("tramadol", null));
            Assert.False(ControlledSubstances.ShouldWarn(null, "Panadol"));
            Assert.False(ControlledSubstances.ShouldWarn(null, null));
        }

        [Fact]
        public void Warning_Is_Labelled_A_Convenience_Not_Compliance()
        {
            // #120: never present the prompt as a legal ruling.
            Assert.Contains("تنبيه مساعد", ControlledSubstances.WarningAr);
            Assert.Contains("ليس حكماً قانونياً", ControlledSubstances.WarningAr);
            Assert.Contains("غير ملزم", ControlledSubstances.TitleAr);
        }

        [Fact]
        public void Warning_Is_A_Dispensing_Prompt_Not_Advice()
        {
            Assert.Contains("روشتة", ControlledSubstances.WarningAr);
        }
    }

    public class BatchStoreTests : IDisposable
    {
        private readonly string _path = Path.Combine(Path.GetTempPath(), "batches-test-" + Guid.NewGuid() + ".db");
        private readonly BatchStore _store;

        public BatchStoreTests() { _store = new BatchStore(_path); }
        public void Dispose() { _store.Dispose(); if (File.Exists(_path)) File.Delete(_path); }

        [Fact]
        public void Fefo_Allocates_Soonest_Expiry_First()
        {
            _store.AddBatch("item-1", "اوجمنتين", 5, new DateTime(2027, 6, 1), "B-late");
            _store.AddBatch("item-1", "اوجمنتين", 3, new DateTime(2027, 1, 1), "B-early");
            var alloc = _store.AllocateFefo("item-1", 4);
            Assert.Equal(2, alloc.Items.Count);
            Assert.True(alloc.Covered);
            Assert.Equal(3, alloc.Items[0].Value);   // finishes the early batch first
            Assert.Equal(1, alloc.Items[1].Value);
        }

        [Fact]
        public void Dispense_Decrements_Clamps_And_Reports_Shortfall()
        {
            var id = _store.AddBatch("item-2", "اموكسيل", 2, new DateTime(2027, 3, 1), null);
            var plan = _store.Dispense("item-2", 5, "sale-x"); // more than on hand
            Assert.Equal(0, _store.TrackedQty("item-2"));
            Assert.False(plan.Covered);
            Assert.Equal(3, plan.Missing);
        }

        [Fact]
        public void Expiring_Soon_Lists_Only_Stocked_Batches_By_Date()
        {
            _store.AddBatch("item-3", "قديم", 4, new DateTime(2026, 1, 1), null);  // already expired
            _store.AddBatch("item-3", "قريب", 4, new DateTime(2026, 12, 15), null);
            _store.AddBatch("item-3", "بعيد", 4, new DateTime(2028, 1, 1), null);
            var expiring = _store.ExpiringSoon(new DateTime(2027, 1, 1), 50);
            Assert.Equal(2, expiring.Count);
            Assert.Equal("قديم", expiring[0].ItemName);
            Assert.Equal("قريب", expiring[1].ItemName);
        }

        [Fact]
        public void Untracked_Item_Allocates_Nothing_And_Still_Sells()
        {
            var alloc = _store.AllocateFefo("no-such-item", 3);
            Assert.Empty(alloc.Items);
            Assert.Equal(3, alloc.Missing);
        }

        [Fact]
        public void Tracked_Qty_Sums_Batches()
        {
            _store.AddBatch("item-4", "x", 10, new DateTime(2027, 1, 1), null);
            _store.AddBatch("item-4", "x", 5, new DateTime(2027, 2, 1), null);
            Assert.Equal(15, _store.TrackedQty("item-4"));
        }
    }
}
