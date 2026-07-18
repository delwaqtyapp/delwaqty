# PHONE_COMMANDS.md — إدارة المشروع من الموبايل عبر OpenCode

> **Last updated:** 2026-07-18
> استخدم هذه الأوامر مباشرة في OpenCode على الموبايل

---

## 1. بيئة العمل (Environment)

```powershell
$env:PUB_CACHE = "E:\app\pub-cache"
$env:GRADLE_USER_HOME = "E:\app\.gradle"
$env:PATH = "E:\app\flutter\bin;$env:PATH"
cd E:\app\delwaqty
```

---

## 2. جودة الكود (Quality Gates)

```powershell
flutter pub get
flutter analyze
flutter test
flutter gen-l10n
```

---

## 3. بناء وتشغيل (Build & Run)

```powershell
flutter build apk --debug --dart-define-from-file=.env.dev
```

تثبيت على الجهاز:
```powershell
adb install -r "E:\app\delwaqty\build\app\outputs\flutter-apk\app-debug.apk"
```

تشغيل التطبيق:
```powershell
adb shell am force-stop com.example.delwaqty
adb shell am start -n com.example.delwaqty/.MainActivity
```

---

## 4. جيت (Git)

```powershell
git status
git diff
git log --oneline -10
git add .
git commit -m "sprint N: description"
git push origin master
git pull origin master
```

---

## 5. قاعدة البيانات (Supabase)

```powershell
# قراءة ملف migration
[System.IO.File]::ReadAllText("E:\app\delwaqty\supabase\migrations\FILENAME.sql")

# تنفيذ migration عبر Management API
$body = '{"query": "QUERY_HERE"}'
$token = "YOUR_SUPABASE_MGMT_TOKEN"
Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/bttnlkmwhorjamzemwda/database/query" -Method POST -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } -Body $body
```

---

## 6. جهاز التطوير (Device)

```powershell
# قائمة الأجهزة المتصلة
adb devices

# سجل الأخطاء
adb logcat -d -s "flutter" -t 50

# مسح السجل
adb logcat -c
```

---

## 7. تشغيل سريع (Quick Dev)

```powershell
$env:PUB_CACHE = "E:\app\pub-cache"; $env:GRADLE_USER_HOME = "E:\app\.gradle"; $env:PATH = "E:\app\flutter\bin;$env:PATH"; cd E:\app\delwaqty; flutter analyze; flutter test
```

```powershell
$env:PUB_CACHE = "E:\app\pub-cache"; $env:GRADLE_USER_HOME = "E:\app\.gradle"; $env:PATH = "E:\app\flutter\bin;$env:PATH"; cd E:\app\delwaqty; flutter build apk --debug --dart-define-from-file=.env.dev; adb install -r "E:\app\delwaqty\build\app\outputs\flutter-apk\app-debug.apk"; adb shell am start -n com.example.delwaqty/.MainActivity
```

---

## 8. معلومات المشروع

| Info | Value |
|------|-------|
| Flutter SDK | `E:\app\flutter` (3.44.6, Dart 3.12.2) |
| Device | DNP NX9 (`A3SQUT5A28003808`) |
| Package | `com.example.delwaqty` |
| Git Remote | `https://github.com/delwaqtyapp/delwaqty` |
| Supabase Project | `bttnlkmwhorjamzemwda` |
| Mgmt Token | في ملف `.env.dev` أو اسأل elayed |
| Google Maps Key | loaded via `.env.dev` (GOOGLE_MAPS_API_KEY) |

---

## 9. Milestones المكتملة

| Milestone | Sprint | Commit |
|-----------|--------|--------|
| M1: Localization + EGP | 28 | `e1ba63d` |
| M2: Transportation Schema | 29 | `6e0e1b3` |
| M3: Passenger Booking | 30 | `0469c40` |
| M4: Dispatch Engine | 31 | `f0d4689` |
| M5: Destination Search | 32 | `1b457d6` |
| M6: Driver Platform | 33 | `7110572` |
| M7: Delivery Platform | 34 | `e66e169` |

## 10. Milestones القادمة

| Milestone | الوصف |
|-----------|-------|
| M8 | Safety (SOS, trusted contacts, live share, OTP pickup) |
| M9 | Admin monitoring dashboard |
| M10 | Payments integration |
