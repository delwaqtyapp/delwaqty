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

## 8.5 السيرفر شغال دايماً (Always-On Server)

> **خلي السيرفر ميفصلش نهائي حتى لو قفلت شاشة الهاتف.**

| Command | الوصف |
|---------|--------|
| `opencode-ctl status` | حالة السيرفر (PIDs / port / tmux / auth) |
| `opencode-ctl restart` | إعادة تشغيل السيرفر بشكل مُدار ومفصول عن الطرفية |
| `opencode-ctl log` | آخر سجلات السيرفر |
| `bash ~/delwaqty/tool/opencode/install.sh` | إعادة تثبيت/إصلاح الإعدادات الكاملة |

**ضمانات عدم الانقطاع:**
1. **Wake lock** — السيرفر مسك `termux-wake-lock` + `wake-lock = true` في
   `~/.termux/termux.properties`، فالـ CPU يفضل شغال والهاتف قافل.
2. **مفصول تماماً** — الشجرة كلها داخل جلسة tmux (`opencode`) بـ `setsid`،
   قفل الشاشة أو إغلاق الطرفية مش بيموتها.
3. **Auto-heal** — لو السيرفر انهار لأي سبب، `opencode-launch` يرجّع يشتغله تلقائياً.
4. **تشغيل تلقائي بعد الريستارت** — `~/.termux/boot/opencode-boot.sh` (بعد إعادة
   الإقلاع: الهاتف → Termux:Boot → `opencode-boot.sh` → tmux → proot → opencode على
   `127.0.0.1:4096`). Termux:Boot + Termux:API **مثبتان بالفعل**؛ لو أعدت تثبيت
   النظام استخدم: `pkg install termux-boot termux-api` ثم **افتح تطبيق Termux:Boot
   مرة واحدة** (Android لا يرسل `BOOT_COMPLETED` للتطبيقات المثبتة ولم تُفتح بعد).

**خطوة يدوية مرة واحدة (مهم):** امنع أندرويد من قتل Termux في الخلفية:
**الإعدادات → التطبيقات → Termux → البطارية → غير مقيد**
(أو من PC: `adb shell dumpsys deviceidle whitelist +com.termux`).

**أمر الاتصال الصحيح (مهم جداً):** عشان تتصل بالسيرفر الشغال — **ممنوع** تعيد تشغيل
السيرفر بأمر `proot-distro login ... serve` (ده أمر تشغيل جديد مربوط بالطرفية =
سبب الانقطاع، وأيضاً بيفشل بـ `ServeError` لو المنفذ مفتوح). الاتصال الصح من داخل
الـ app (نفس بيئة ubuntu):

```bash
export OPENCODE_SERVER_PASSWORD=test-local-only
opencode attach http://127.0.0.1:4096
```

لو الباش بيعملك alias `oc`، يكفي تكتب:

```bash
oc
```

الملفات الأصلية في الريبو: `tool/opencode/` (هي المصدر — `opencode-ctl`,
`opencode-launch`, `opencode-boot.sh`, `install.sh`, `README.md`).

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
