namespace Delwaqty.Pos.Core.Catalog
{
    /// <summary>One row of the MoH-aligned drug catalog, cached locally for offline lookup.</summary>
    public sealed class DrugProduct
    {
        public string Id;
        public string NameEn;
        public string NameAr;
        public string ActiveIngredient;
        public string Manufacturer;
        public decimal? OfficialPriceEgp;  // MoH official price list (التسعيرة الرسمية)
        public string Barcode;
        public string DosageForm;
        public string Strength;
        public string Category;
        public string SearchNorm;
        public bool IsActive = true;
    }
}
