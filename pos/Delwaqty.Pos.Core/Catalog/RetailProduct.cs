namespace Delwaqty.Pos.Core.Catalog
{
    /// <summary>
    /// One row of a retail merchant's own products table, cached locally for
    /// offline lookup. Mirrors the `products` array of cashier_sync_pull.
    /// </summary>
    public sealed class RetailProduct
    {
        public string Id;
        public string Name;
        public string NameAr;
        public decimal Price;
        public decimal? Stock;
        public string Barcode;
        public string SearchNorm;
        public string UpdatedAt;
    }
}
