; Delwaqty POS installer - see pos/docs/installer-and-autoupdate.md
; Single shop build (DelwaqtyShopPos). Two payloads, same script:
;   net8.0-windows self-contained (Windows 10+)
;   net48 + .NET Framework 4.8 web bootstrapper (Windows 7 SP1 fallback)
; CI builds both; the download site picks by Windows version.
;
; Build (Inno Setup 6):
;   iscc /DSourceDir=publish\shop-net8 /DOutputBase=delwaqty-cashier-setup-net8-EXPERIMENTAL pos\installer\delwaqty.iss
;   iscc /DSourceDir=publish\shop-net48 /DNet48Bootstrapper=artifacts\ndp48-web.exe /DOutputBase=delwaqty-cashier-setup-net48-EXPERIMENTAL pos\installer\delwaqty.iss

; Path macros (SourceDir, Net48Bootstrapper, OutputDir) are resolved
; RELATIVE TO THIS SCRIPT'S DIRECTORY when passed relative - callers must
; pass ABSOLUTE paths (the CI workflow does, from $PWD). The defaults below
; are for local experiments only and follow the same rule.
#ifndef SourceDir
  #define SourceDir "publish\shop-net8"
#endif
#ifndef OutputBase
  #define OutputBase "delwaqty-cashier-setup-EXPERIMENTAL"
#endif
#ifndef OutputDir
  #define OutputDir "installer-output"
#endif
#define AppVersion "1.0.0"

[Setup]
; Fixed once: never change, or upgrades stop detecting the installed app.
AppId={{2AB17727-0344-429A-A483-09C214E72080}
AppName=Delwaqty POS
AppVersion={#AppVersion}
AppPublisher=Delwaqty
DefaultDirName={autopf}\DelwaqtyPos
DefaultGroupName=Delwaqty POS
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBase}
; Per-machine install (NOT per-user): every Windows user on the shop PC runs
; the same app and the same data dir - per-user installs scatter the SQLite
; DB and break multi-shift shops.
PrivilegesRequired=admin
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Auto-update path launches the downloaded setup with /VERYSILENT /NORESTART.
; Signing: unsigned builds trigger SmartScreen - see the launch-blocker note
; in pos/docs/installer-and-autoupdate.md.

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"

[Tasks]
Name: "desktopicon"; Description: "Desktop shortcut"; GroupDescription: "Shortcuts:"

[Dirs]
; Shared per-machine data dir (survives updates, writable by every user).
; The app creates it too; pre-creating with open permissions avoids
; first-run ACL surprises when a second Windows user runs the app.
Name: "{commonappdata}\DelwaqtyPos"; Permissions: everyone-modify

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
#ifdef Net48Bootstrapper
Source: "{#Net48Bootstrapper}"; DestDir: "{tmp}"; Flags: deleteafterinstall
#endif

[Icons]
Name: "{group}\Delwaqty POS"; Filename: "{app}\DelwaqtyShopPos.exe"
Name: "{commondesktop}\Delwaqty POS"; Filename: "{app}\DelwaqtyShopPos.exe"; Tasks: desktopicon

[Run]
#ifdef Net48Bootstrapper
; Install .NET Framework 4.8 only when the machine lacks it (Release >= 528040).
Filename: "{tmp}\ndp48-web.exe"; Parameters: "/q /norestart"; Check: Not Net48Installed; StatusMsg: "Installing .NET Framework 4.8..."
#endif
Filename: "{app}\DelwaqtyShopPos.exe"; Description: "Run Delwaqty POS"; Flags: nowait postinstall skipifsilent

[Code]
function Net48Installed: Boolean;
var
  Release: Cardinal;
begin
  Result := RegQueryDWordValue(HKLM,
    'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', Release)
    and (Release >= 528040);
end;
