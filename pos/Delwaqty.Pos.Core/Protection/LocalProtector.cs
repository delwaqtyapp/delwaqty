using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace Delwaqty.Pos.Core.Protection
{
    /// <summary>
    /// User-bound protection for local secrets (review #114/#115).
    /// On Windows this is DPAPI (ProtectedData) in CurrentUser scope.
    ///
    /// Supported deployment model: ONE dedicated Windows account per shop PC
    /// (all cashiers share that Windows login; staff identity inside the app
    /// is the structural fix, see docs/server-change-proposals-2026-11-23.md).
    ///
    /// Accepted threat boundary (documented for support):
    /// - A data directory copied to another PC, or read by a DIFFERENT Windows
    ///   user on the same PC, cannot be unprotected.
    /// - Any process running as the SAME Windows user CAN unprotect: DPAPI is
    ///   user-bound, not process-bound. The ACL on the data dir (see
    ///   DataDirSecurity) keeps other local users out; it cannot keep the
    ///   owning user's own processes out.
    /// - The device-bound server license (one key, one PC) remains the real
    ///   enforcement against cloning; support resets the binding when a PC is
    ///   replaced.
    ///
    /// Non-Windows exists only so the cross-platform test suite and CI can
    /// exercise the logic; the shipped app targets Windows exclusively.
    /// </summary>
    public interface ILocalProtector
    {
        string Name { get; }
        byte[] Protect(byte[] plain);
        byte[] Unprotect(byte[] blob);
    }

    /// <summary>Windows DPAPI (CurrentUser scope) with a per-purpose entropy.</summary>
    public sealed class DpapiProtector : ILocalProtector
    {
        private readonly byte[] _entropy;

        public DpapiProtector(string purpose)
        {
            _entropy = Encoding.UTF8.GetBytes("DelwaqtyPos/" + (purpose ?? "") + "/v1");
        }

        public string Name { get { return "dpapi-currentuser"; } }

        public byte[] Protect(byte[] plain)
        {
            return ProtectedData.Protect(plain, _entropy, DataProtectionScope.CurrentUser);
        }

        public byte[] Unprotect(byte[] blob)
        {
            return ProtectedData.Unprotect(blob, _entropy, DataProtectionScope.CurrentUser);
        }
    }

    /// <summary>
    /// Development/test fallback for non-Windows hosts (CI). NOT secure and
    /// never used by the shipped Windows app: it only keeps the code paths
    /// exercisable off-Windows.
    /// </summary>
    public sealed class PlaintextProtector : ILocalProtector
    {
        public string Name { get { return "plaintext-dev-only"; } }
        public byte[] Protect(byte[] plain) { return (byte[])plain.Clone(); }
        public byte[] Unprotect(byte[] blob) { return (byte[])blob.Clone(); }
    }

    public static class LocalProtector
    {
        /// <summary>
        /// The protector for one purpose ("device-key", "session-cred").
        /// overrideForTests lets tests inject a reversible protector; on
        /// Windows the DPAPI protector is always used otherwise.
        /// </summary>
        public static ILocalProtector ForPurpose(string purpose, ILocalProtector overrideForTests = null)
        {
            if (overrideForTests != null) return overrideForTests;
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                return new DpapiProtector(purpose);
            return new PlaintextProtector();
        }
    }

    /// <summary>
    /// The per-install device key (HMAC key for the license seal), itself
    /// stored DPAPI-protected (review #114: it previously sat in plaintext
    /// base64 next to the data it protected).
    /// File format: "DP1:" + base64(protect(key)).
    ///
    /// Legacy plaintext keys migrate ONCE: a marker file (device.key.dp1) is
    /// written with the first protected save, and plaintext content is never
    /// accepted again afterwards. Without the marker a planted plaintext key
    /// would let a directory writer substitute a key they know and forge
    /// seals (review #114 follow-up).
    ///
    /// A protected blob that fails to unprotect (foreign user/machine, or
    /// corrupted file) is NOT a crash: the key is regenerated and the old
    /// one discarded, which invalidates every local seal and forces a fresh
    /// online activation (security review LOW-1).
    /// </summary>
    public static class DeviceKeyStore
    {
        public const string BlobPrefix = "DP1:";
        public const string MarkerFileName = "device.key.dp1";

        public static byte[] GetOrCreate(string rootDir, ILocalProtector protector = null)
        {
            System.IO.Directory.CreateDirectory(rootDir);
            var path = System.IO.Path.Combine(rootDir, "device.key");
            var markerPath = System.IO.Path.Combine(rootDir, MarkerFileName);
            protector = protector ?? LocalProtector.ForPurpose("device-key");
            if (System.IO.File.Exists(path))
            {
                var text = (System.IO.File.ReadAllText(path) ?? "").Trim();
                if (text.StartsWith(BlobPrefix, StringComparison.Ordinal))
                {
                    try
                    {
                        var key = protector.Unprotect(Convert.FromBase64String(text.Substring(BlobPrefix.Length)));
                        TouchMarker(markerPath);
                        return key;
                    }
                    catch
                    {
                        // Foreign or corrupted blob: regenerate (old seals die,
                        // reactivation required) instead of crashing at startup.
                        var fresh = Licensing.LocalLicenseSeal.NewDeviceKey();
                        Save(path, fresh, protector);
                        TouchMarker(markerPath);
                        return fresh;
                    }
                }
                if (System.IO.File.Exists(markerPath))
                {
                    // A protected key existed before: this plaintext content was
                    // planted after the migration. Never adopt it (review #114):
                    // regenerate so seals forged with the planted key never
                    // verify, forcing a fresh online activation.
                    var fresh2 = Licensing.LocalLicenseSeal.NewDeviceKey();
                    Save(path, fresh2, protector);
                    return fresh2;
                }
                // Genuine legacy plaintext base64 key: migrate once, then mark.
                var legacy = Convert.FromBase64String(text);
                Save(path, legacy, protector);
                TouchMarker(markerPath);
                return legacy;
            }
            var created = Licensing.LocalLicenseSeal.NewDeviceKey();
            Save(path, created, protector);
            TouchMarker(markerPath);
            return created;
        }

        private static void Save(string path, byte[] key, ILocalProtector protector)
        {
            System.IO.File.WriteAllText(path,
                BlobPrefix + Convert.ToBase64String(protector.Protect(key)));
        }

        private static void TouchMarker(string markerPath)
        {
            if (!System.IO.File.Exists(markerPath))
                System.IO.File.WriteAllText(markerPath, "dp1");
        }
    }

    /// <summary>
    /// Hardens the data directory ACL on Windows (review #114): the directory
    /// under CommonApplicationData is created loose by default. We disable
    /// inheritance and grant exactly SYSTEM + Administrators (full) and the
    /// CURRENT Windows user (full) — the supported model is one dedicated
    /// Windows account per shop PC, so other local users get nothing.
    /// Best-effort: failure never blocks startup. No-op off Windows.
    /// </summary>
    public static class DataDirSecurity
    {
        public static void Harden(string dir)
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) return;
            try
            {
                var info = new DirectoryInfo(dir);
                var sec = new System.Security.AccessControl.DirectorySecurity();
                sec.SetAccessRuleProtection(true, false); // disable + drop inherited rules
                void GrantSid(string sid, System.Security.AccessControl.FileSystemRights rights)
                {
                    sec.AddAccessRule(new System.Security.AccessControl.FileSystemAccessRule(
                        new System.Security.Principal.SecurityIdentifier(sid),
                        rights,
                        System.Security.AccessControl.InheritanceFlags.ContainerInherit |
                        System.Security.AccessControl.InheritanceFlags.ObjectInherit,
                        System.Security.AccessControl.PropagationFlags.None,
                        System.Security.AccessControl.AccessControlType.Allow));
                }
                GrantSid("S-1-5-18", System.Security.AccessControl.FileSystemRights.FullControl);     // SYSTEM
                GrantSid("S-1-5-32-544", System.Security.AccessControl.FileSystemRights.FullControl); // Administrators
                var currentUser = Environment.UserDomainName + "\\" + Environment.UserName;
                sec.AddAccessRule(new System.Security.AccessControl.FileSystemAccessRule(
                    currentUser,
                    System.Security.AccessControl.FileSystemRights.FullControl,
                    System.Security.AccessControl.InheritanceFlags.ContainerInherit |
                    System.Security.AccessControl.InheritanceFlags.ObjectInherit,
                    System.Security.AccessControl.PropagationFlags.None,
                    System.Security.AccessControl.AccessControlType.Allow));
                info.SetAccessControl(sec);
            }
            catch { /* hardening is best-effort; never block the cashier from opening */ }
        }
    }
}
