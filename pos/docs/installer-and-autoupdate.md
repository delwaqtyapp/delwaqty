# Installer and auto-update path — Delwaqty POS

Constraints from the market: weak shop PCs, some still on Windows 7, metered
connections, no IT staff. The install and update path must be one file, one
click, and resumable.

## Installer: Inno Setup (recommended)

Why Inno Setup over MSIX/ClickOnce/Squirrel:
- MSIX requires Windows 10 1809+ — excludes Win7.
- ClickOnce works on Win7 but installs per-user into an obfuscated path and
  its update CDN story is poor on flaky connections.
- Squirrel.Windows is unmaintained and shaky on Win7.
- Inno Setup produces a single small `DelwaqtyPosSetup.exe`, runs on Win7 SP1+,
  supports Arabic UI, silent install for remote support, and can bundle the
  .NET Framework 4.8 web bootstrapper for machines that lack it.

Deliverable script (to add as `pos/installer/delwaqty.iss` when built on
Windows):
- AppId GUID fixed once, `DefaultDirName={autopf}\DelwaqtyPos`.
- Files: the `net48` publish output (single-folder, no framework dependency
  beyond 4.8) OR the `net8.0-windows` self-contained build for Win10+ —
  ship two installers, the site picks by Windows version.
- `PrivilegesRequired=lowest` is NOT used: install per-machine so every
  Windows user on the shop PC runs the same data. (Per-user install scatters
  the SQLite DB and breaks multi-shift shops.)
- Data directory: `{commonappdata}\DelwaqtyPos` (writable, survives updates);
  first-run code creates it and the SQLite files live there, never next to
  the exe.
- Prerequisite check: .NET 4.8 registry probe
  (`HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\Release >= 528040`),
  download the bootstrapper only when missing.

## Auto-update: manifest + swap-on-restart

Simplest scheme that survives weak connections, no third-party updater:

1. **Manifest**: a small static JSON file at a fixed URL (Cloudflare R2, same
   infra as app media), e.g. `https://cdn.delwaqty.com/pos/stable.json`:
   `{"version": "1.1.0", "url": ".../DelwaqtyPosSetup-1.1.0.exe",
     "sha256": "...", "min_windows": "6.1", "mandatory": false}`
2. **Check**: the app checks the manifest on startup and then every 6 hours
   (one tiny request — cheap on metered links).
3. **Download**: Background Intelligent Transfer-style resume is overkill;
   a plain ranged HttpClient download to
   `{commonappdata}\DelwaqtyPos\updates\setup.exe.part` with resume on
   restart covers shop connections. Verify the SHA-256 before anything else.
4. **Apply**: on the next app start (or when the cashier chooses "حدّث الآن"
   after close), launch the downloaded installer with `/VERYSILENT /NORESTART`
   and exit; the installer replaces files and relaunches the app. The SQLite
   data is untouched (it lives in the data dir).
5. **Mandatory flag**: when a server migration requires a minimum client
   (e.g. a new sync-op version), set `"mandatory": true`; the app then blocks
   selling until updated, with a clear Arabic message. Normal releases stay
   optional so a shop is never forced mid-rush.

Rollback: keep the previous installer in `updates\` and a `stable.json`
pointer change on the CDN instantly un-publishes a bad release; affected
shops reinstall the kept installer manually (remote support path: AnyDesk —
already the norm for Egyptian shops).

Signing: buy a code-signing cert before public distribution; unsigned
installers trigger SmartScreen warnings that shop owners will not click past.
Note this as a launch blocker in the rollout plan (cost is the owner's call).

## Version contract
- Client sends its version in the `X-Pos-Version` header on every sync call.
- Server never breaks an old client silently: new sync ops are additive
  (unknown op types return `UNKNOWN_OP` per-op without failing the batch).
