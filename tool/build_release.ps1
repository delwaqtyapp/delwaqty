$ErrorActionPreference = 'Stop'
$env:PUB_CACHE = 'E:\app\pub-cache'
$env:GRADLE_USER_HOME = 'E:\app\.gradle'
$env:CRASHLYTICS_UPLOAD = 'false'
$flutter = 'E:\app\flutter\bin\flutter.bat'
$flavors = @('customer', 'admin', 'driver', 'provider')

foreach ($f in $flavors) {
    Write-Host "===== APK release split-per-ABI: $f ====="
    & $flutter build apk --release --split-per-abi --flavor $f --target lib/$f/main.dart --dart-define-from-file=.env.dev
    if ($LASTEXITCODE -ne 0) { throw "APK build FAILED for $f" }

    Write-Host "===== AAB release: $f ====="
    & $flutter build appbundle --release --flavor $f --target lib/$f/main.dart --dart-define-from-file=.env.dev
    if ($LASTEXITCODE -ne 0) { throw "AAB build FAILED for $f" }
}

Write-Host "ALL FOUR DELWAQTY APPS BUILT SUCCESSFULLY (APK + AAB), ZERO ERRORS."
