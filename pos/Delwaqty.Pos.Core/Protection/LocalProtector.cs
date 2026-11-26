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
    /// Plaintext content is NEVER adopted (review #115 follow-up): a marker
    /// file can be deleted by the same directory writer who plants a chosen
    /// key, so any migration path is a forge-seals path. A non-"DP1:" file
    /// — legacy plaintext or planted — is overwritten with a fresh protected
    /// key. Consequence: every local seal and legacy payload HMAC stops
    /// verifying and the install must re-activate ONLINE. Data recovery: all
    /// other files (outbox, sales, scopes) stay exactly where they are; the
    /// pre-DP1 flat layout is NOT auto-migrated afterwards (its payload can
    /// no longer be verified), so support migrates those files manually.
    ///
    /// A protected blob that fails to unprotect (foreign user/machine, or
    /// corrupted file) follows the same recovery flow instead of crashing
    /// (security review LOW-1): regenerate, keep all other data, reactivate
    /// online.
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
                    try
                    {
                        return protector.Unprotect(Convert.FromBase64String(text.Substring(BlobPrefix.Length)));
                    }
                    catch
                    {
                        // Foreign or corrupted blob: regenerate (old seals die,
                        // data stays, reactivation required) — never crash.
                        var fresh = Licensing.LocalLicenseSeal.NewDeviceKey();
                        Save(path, fresh, protector);
                        return fresh;
                    }
                }
                // Plaintext content — legacy or planted — is never adopted.
                var freshPlain = Licensing.LocalLicenseSeal.NewDeviceKey();
                Save(path, freshPlain, protector);
                return freshPlain;
            }
            var created = Licensing.LocalLicenseSeal.NewDeviceKey();
            Save(path, created, protector);
            return created;
        }

        private static void Save(string path, byte[] key, ILocalProtector protector)
        {
            System.IO.File.WriteAllText(path,
                BlobPrefix + Convert.ToBase64String(protector.Protect(key)));
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
