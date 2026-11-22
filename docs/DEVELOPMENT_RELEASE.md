# One development release

During polishing, the public app version stays **1.0.0**. The integer after
`+` in pubspec.yaml increases only when distributing a replacement build.
It is an internal Android/OTA code, not a product release number.

The same package IDs and signing key must be retained. Android permits an
update with an equal or higher code, but OTA only offers strictly higher
codes. Never reset the internal code for the first Play release. Play can
start at visible version 1.0.0 with any unused code above the dev builds.

## Publish

1. Increase only the internal build code. Keep pubspec `1.0.0+N` and the OTA
   template's `version: N`, `versionName: 1.0.0` in sync.
2. Push a complete commit. Wait for **all** CI/CD jobs, including Test and
   Analyze & Format, to pass. Apply the normal code-review gate.
3. With gh authenticated, run `python3 tool/publish_development.py RUN_ID`.
   The script refuses a partial/failed CI run, downloads its four APKs,
   checks the established signing certificate, writes per-channel SHA-256,
   and verifies every uploaded APK and manifest by downloading them again.
4. The only release is `development`, titled `Development build`. APK asset
   names contain the internal build code so caches cannot confuse two builds.
   Upload APKs before replacing `versions.json`; remove old APKs afterward.
   The manifest records the exact source commit. The stable tag points to the
   initial development release, not necessarily the newest APK source.
5. Do not create a version announcement for every fix. OTA already checks
   for newer internal codes. If an announcement is needed, use neutral text,
   not a new public version number.

The app asks for fresh release metadata/manifests with a cache-busting query.
An old installed client can still discover `development` through the existing
GitHub latest-release API and use the same manifest schema. It may briefly see
cached metadata; retrying later remains safe because APK SHA-256 is enforced.
No release process may lower the code or bypass the signing/checksum checks.

## First Play release

Keep the visible version 1.0.0 and select an internal code greater than every
distributed dev build. Keep signing compatibility with existing installs.
After launch, choose visible 1.0.1 or 2.0.0 when the actual product release
warrants it. Internal codes continue increasing regardless of visible names.

References:
- https://developer.android.com/studio/publish/versioning
- https://developer.android.com/google/play/app-updates
