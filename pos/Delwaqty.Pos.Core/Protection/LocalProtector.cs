using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace Delwaqty.Pos.Core.Protection
{
    /// <summary>
    /// Machine/user-bound protection for local secrets (review #114/#115).
    /// On Windows this is DPAPI (ProtectedData) in LocalMachine scope: shop
    /// PCs are shared by several Windows users across shifts, and the data
    /// directory is per-machine. LocalMachine scope still binds the blob to
    /// THIS machine: a data directory copied to another PC cannot be
    /// unprotected there. Known limitation (documented for support): DPAPI
    /// is machine-bound, not license-bound — any process running on the same
    /// PC can unprotect. The device-bound license remains per license key;
    /// support resets the binding when a PC is replaced.
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

    /// <summary>Windows DPAPI (LocalMachine scope) with a per-purpose entropy.</summary>
    public sealed class DpapiProtector : ILocalProtector
    {
        private readonly byte[] _entropy;

        public DpapiProtector(string purpose)
        {
            _entropy = Encoding.UTF8.GetBytes("DelwaqtyPos/" + (purpose ?? "") + "/v1");
        }

        public string Name { get { return "dpapi"; } }

        public byte[] Protect(byte[] plain)
        {
            return ProtectedData.Protect(plain, _entropy, DataProtectionScope.LocalMachine);
        }

        public byte[] Unprotect(byte[] blob)
        {
            return ProtectedData.Unprotect(blob, _entropy, DataProtectionScope.LocalMachine);
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
    /// base64 next to the data it protected). Legacy plaintext files are
    /// migrated on first read.
    /// File format: "DP1:" + base64(protect(key)).
    /// </summary>
    public static class DeviceKeyStore
    {
        public const string BlobPrefix = "DP1:";

        public static byte[] GetOrCreate(string rootDir, ILocalProtector protector = null)
        {
            System.IO.Directory.CreateDirectory(rootDir);
            var path = System.IO.Path.Combine(rootDir, "device.key");
            protector = protector ?? LocalProtector.ForPurpose("device-key");
            if (System.IO.File.Exists(path))
            {
                var text = (System.IO.File.ReadAllText(path) ?? "").Trim();
                if (text.StartsWith(BlobPrefix, StringComparison.Ordinal))
                {
                    return protector.Unprotect(Convert.FromBase64String(text.Substring(BlobPrefix.Length)));
                }
                // Legacy plaintext base64 key: load it, then re-save protected.
                var legacy = Convert.FromBase64String(text);
                Save(path, legacy, protector);
                return legacy;
            }
            var key = Licensing.LocalLicenseSeal.NewDeviceKey();
            Save(path, key, protector);
            return key;
        }

        private static void Save(string path, byte[] key, ILocalProtector protector)
        {
            System.IO.File.WriteAllText(path,
                BlobPrefix + Convert.ToBase64String(protector.Protect(key)));
        }
    }

    /// <summary>
    /// Hardens the shared data directory ACL on Windows (review #114): the
    /// directory under CommonApplicationData is created loose by default.
    /// We disable inheritance and grant exactly SYSTEM + Administrators
    /// (full) and interactive Users (modify — non-admin cashiers across
    /// shifts must write), dropping Everyone/anonymous-style entries.
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
                void Grant(string sid, System.Security.AccessControl.FileSystemRights rights)
                {
                    sec.AddAccessRule(new System.Security.AccessControl.FileSystemAccessRule(
                        new System.Security.Principal.SecurityIdentifier(sid),
                        rights,
                        System.Security.AccessControl.InheritanceFlags.ContainerInherit |
                        System.Security.AccessControl.InheritanceFlags.ObjectInherit,
                        System.Security.AccessControl.PropagationFlags.None,
                        System.Security.AccessControl.AccessControlType.Allow));
                }
                Grant("S-1-5-18", System.Security.AccessControl.FileSystemRights.FullControl);        // SYSTEM
                Grant("S-1-5-32-544", System.Security.AccessControl.FileSystemRights.FullControl);    // Administrators
                Grant("S-1-5-32-545", System.Security.AccessControl.FileSystemRights.Modify);         // Users
                info.SetAccessControl(sec);
            }
            catch { /* hardening is best-effort; never block the cashier from opening */ }
        }
    }
}
