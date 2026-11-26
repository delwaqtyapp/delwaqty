using System;
using System.IO;

namespace Delwaqty.Pos.Core.Sync
{
    /// <summary>
    /// Stable per-install device id used for license binding. A random GUID
    /// written once into the app data directory; reinstalling or wiping the
    /// data dir intentionally counts as a new device (the license is
    /// device-bound, so support resets the binding — see license doc).
    /// </summary>
    public static class DeviceId
    {
        public static string GetOrCreate(string dataDir)
        {
            Directory.CreateDirectory(dataDir);
            var path = Path.Combine(dataDir, "device.id");
            if (File.Exists(path))
            {
                var existing = (File.ReadAllText(path) ?? "").Trim();
                Guid g;
                if (Guid.TryParse(existing, out g)) return g.ToString("D");
            }
            var fresh = Guid.NewGuid().ToString("D");
            File.WriteAllText(path, fresh);
            return fresh;
        }
    }

    /// <summary>App data locations. Per-machine, shared by every Windows user
    /// on the shop PC (multi-shift shops), per pos/docs/installer-and-autoupdate.md.</summary>
    public static class AppPaths
    {
        public static string DataDir()
        {
            var baseDir = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
            if (string.IsNullOrEmpty(baseDir))
                baseDir = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            var dir = Path.Combine(baseDir, "DelwaqtyPos");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }
}
