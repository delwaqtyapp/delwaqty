namespace Delwaqty.Pos.Wpf
{
    /// <summary>
    /// Publishable client config — the same values the Flutter apps ship in
    /// every APK (lib/config/app_config.dart). The anon key is designed to be
    /// public; data access is enforced by RLS and the merchant's sign-in.
    /// </summary>
    internal static class PosConfig
    {
        public const string SupabaseUrl = "https://bttnlkmwhorjamzemwda.supabase.co";
        public const string SupabaseAnonKey =
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ0dG5sa213aG9yamFtemVtd2RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxODc4MzgsImV4cCI6MjA5OTc2MzgzOH0.IsksTaJz-k9Gbc-6f7Is6HxWd0wOZRhSGpYI00gYkH4";

        public const string AppVersion = "1.0.0";

#if POS_RETAIL
        public const string BuildFlavor = "Retail";
        public const string DefaultTitle = "دلوقتي - كاشير المحلات";
        public const string ExeName = "DelwaqtyShopPos";
#else
        public const string BuildFlavor = "Pharmacy";
        public const string DefaultTitle = "دلوقتي - كاشير الصيدليات";
        public const string ExeName = "DelwaqtyPharmacyPos";
#endif

        /// <summary>How often the background sync flushes the outbox and pulls.</summary>
        public const int SyncIntervalSeconds = 60;

        /// <summary>Expiry warning window for pharmacy batches (days).</summary>
        public const int ExpiryWarnDays = 90;
    }
}
