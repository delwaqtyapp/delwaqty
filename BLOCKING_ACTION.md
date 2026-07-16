# BLOCKING_ACTION.md

> **Last updated:** 2026-07-16
> **Status:** All 4 actions required to proceed with Phase 3

---

## Summary

The Delwaqty platform is fully built and production-hardened. Four external services must be configured before the first real production flow can be validated.

| # | Service | Est. Time | Difficulty | Billing | Free Tier |
|---|---------|-----------|------------|---------|-----------|
| 1 | Supabase DB Schema | 5 min | Easy | No | Yes (2 free projects) |
| 2 | Firebase Project | 10 min | Easy | No | Yes (Spark plan) |
| 3 | Google Maps API Key | 15 min | Medium | Optional | Yes ($200/mo free) |
| 4 | Cloudflare R2 | 10 min | Medium | No | Yes (10GB free) |

**Total estimated time: ~40 minutes**

---

# ACTION 1: Deploy Supabase Database Schema

## English

### What is this?

Supabase is the backend database for Delwaqty. We need to create 14 database tables, indexes, security policies, and functions by running a SQL script.

### Why is this required?

Without the database, the app cannot store user data, orders, products, or any business data. Every feature depends on this.

### What happens after?

I will automatically:
1. Verify all 14 tables exist
2. Verify 29 RLS security policies
3. Verify 16 indexes
4. Replace all mock repositories with real Supabase implementations
5. Delete obsolete mock code
6. Build the first end-to-end production flow

### Step-by-step instructions

**Step 1:** Open Supabase Dashboard

https://supabase.com/dashboard

Click: **"Log in"** (use your Supabase account)

**Step 2:** Select your project

Click on the project named **"bttnlkmwhorjamzemwda"**

**Step 3:** Open SQL Editor

Left sidebar → click **"SQL Editor"**

**Step 4:** Create a new query

Click **"New query"** button (top right)

**Step 5:** Paste the schema

Open the file:
```
E:\app\delwaqty\supabase\migrations\001_initial_schema.sql
```

Copy ALL contents and paste into the SQL Editor.

**Step 6:** Run the script

Click **"Run"** button (or press Ctrl+Enter)

Wait for "Success" message.

**Step 7:** Verify tables

Left sidebar → click **"Table Editor"**

You should see these 14 tables:
- users, admin_users, merchants, products, categories
- orders, order_items, reviews, favorites, drivers
- coupons, notifications, activity_logs, platform_settings

### Files that will be modified

| File | Change |
|------|--------|
| `lib/data/datasources/remote/supabase_profile_data_source.dart` | Connect to real `users` table |
| `lib/data/repositories/user_repository_impl.dart` | Replace mock with real CRUD |
| `lib/data/repositories/profile_repository_impl.dart` | Replace mock with real CRUD |
| All feature repositories | Connect to real tables |

### Credentials required

None. The Supabase project is already configured with credentials in `.env.dev`.

### Security note

The database has Row Level Security (RLS) enabled. Users can only access their own data.

---

## بالعربي (Arabic)

### ما هذا؟

Supabase هو قاعدة البيانات backend للتطبيق. نحتاج لإنشاء 14 جدول database مع فهارس وسياسات أمان تشغيل سكريبت SQL.

### لماذا هذا مطلوب؟

بدون قاعدة البيانات، لا يمكن للتطبيق حفظ بيانات المستخدمين أو الطلبات أو المنتجات. كل ميزة تعتمد على هذا.

### ماذا يحدث بعد؟

سأقوم تلقائياً بـ:
1. التحقق من وجود جميع الجداول الـ 14
2. التحقق من سياسات الأمان
3. استبدال جميع المستودعات الوهمية بمستودعات حقيقية
4. حذف الكود القديم غير الضروري
5. بناء أول تدفق إنتاجي كامل

### خطوات التنفيذ

**الخطوة 1:** افتح لوحة تحكم Supabase

https://supabase.com/dashboard

اضغط: "تسجيل الدخول" (استخدم حساب Supabase الخاص بك)

**الخطوة 2:** اختر مشروعك

اضغط على المشروع باسم "bttnlkmwhorjamzemwda"

**الخطوة 3:** افتح محرر SQL

الشريط الجانبي → اضغط "SQL Editor"

**الخطوة 4:** أنشئ استعلاماً جديداً

اضغط زر "New query" (أعلى اليمين)

**الخطوة 5:** الصق المخطط

افتح الملف:
```
E:\app\delwaqty\supabase\migrations\001_initial_schema.sql
```

انسخ جميع المحتويات والصقها في محرر SQL.

**الخطوة 6:** شغل السكريبت

اضغط زر "Run" (أو اضغط Ctrl+Enter)

انتظر رسالة "Success".

**الخطوة 7:** تحقق من الجداول

الشريط الجانبي → اضغط "Table Editor"

يجب أن ترى 14 جدول.

### الملفات التي سيتم تعديلها

جميع مستودعات البيانات في التطبيق sẽ تتصل بقاعدة البيانات الحقيقية.

### ملاحظة أمنية

قاعدة البيانات مفعلة فيها RLS (سياسات مستوى الصف). كل مستخدم يمكنه الوصول لبياناته فقط.

### الوقت المقدر: 5 دقائق

### الصعوبة: سهل

### هل يحتاج دفع؟ لا

### هل يحتاج بطاقة دفع؟ لا

### هل.free tier كافٍ؟ نعم

---
---

# ACTION 2: Create Firebase Project

## English

### What is this?

Firebase provides push notifications, crash reporting, analytics, and performance monitoring for the Delwaqty app.

### Why is this required?

Without Firebase:
- No push notifications
- No crash reports when errors occur
- No user analytics
- No performance monitoring

### What happens after?

I will automatically:
1. Replace empty Firebase initialization with real project config
2. Enable crash reporting for all errors
3. Enable analytics event tracking
4. Enable performance monitoring
5. Wire push notification token refresh

### Step-by-step instructions

**Step 1:** Open Firebase Console

https://console.firebase.google.com

Click: **"Create a project"** (or "Add project")

**Step 2:** Project setup

- Project name: **"Delwaqty"**
- Click **"Continue"**
- Google Analytics: **"Disable"** (we use our own)
- Click **"Create project"**
- Wait for creation to complete

**Step 3:** Add Android app

- Click the **Android icon** (or Project Settings → "Add app" → Android)
- Android package name: **`com.example.delwaqty`**
- App nickname: **"Delwaqty Android"**
- Click **"Register app"**

**Step 4:** Download google-services.json

- Click **"Download google-services.json"**
- The file will be named: `google-services.json`

**Step 5:** Place the file

Copy `google-services.json` to:
```
E:\app\delwaqty\android\app\google-services.json
```

**Step 6:** Continue in Firebase Console

- Click **"Next"** (skip the SDK instructions, I handle this)
- Click **"Continue to console"**

### File that will be placed

| File | Location | Purpose |
|------|----------|---------|
| `google-services.json` | `android/app/google-services.json` | Android Firebase config |

### File that will be modified

| File | Change |
|------|--------|
| `lib/main.dart` | Replace empty FirebaseOptions with real project config |
| `android/app/build.gradle.kts` | Verify google-services plugin |

### Credentials generated

| Credential | Purpose | Example format |
|------------|---------|----------------|
| `google-services.json` | Firebase Android config | JSON file with project_id, api_key |

### Security note

`google-services.json` contains only public identifiers (API keys are restricted by Android package name). It is safe to commit to a private repository. Never commit the `google-services.json` to a public repo.

### Free tier limits (Spark plan)

- 50K messages/day (FCM)
- 10M analytics events/month
- 10M Crashlytics events/month
- More than sufficient for launch

### Time: 10 minutes

### Difficulty: Easy

### Billing: No (free Spark plan)

### Payment required: No

---

## بالعربي (Arabic)

### ما هذا؟

Firebase يوفر إشعارات الدفع، تقارير الأخطاء، تحليلات المستخدمين، ومراقبة الأداء لتطبيق Delwaqty.

### لماذا هذا مطلوب؟

بدون Firebase:
- لا إشعارات دفع
- لا تقارير أخطاء
- لا تحليلات مستخدمين
- لا مراقبة أداء

### خطوات التنفيذ

**الخطوة 1:** افتح وحدة تحكم Firebase

https://console.firebase.google.com

اضغط: "Create a project" (إنشاء مشروع)

**الخطوة 2:** إعداد المشروع

- اسم المشروع: "Delwaqty"
- اضغط "Continue"
- Google Analytics: "Disable" (نستخدم نظامنا الخاص)
- اضغط "Create project"
- انتظر حتى يكتمل الإنشاء

**الخطوة 3:** إضافة تطبيق Android

- اضغط على أيقونة Android
- اسم الحزمة: `com.example.delwaqty`
- اسم التطبيق: "Delwaqty Android"
- اضغط "Register app"

**الخطوة 4:** تحميل ملف الإعدادات

- اضغط "Download google-services.json"
- الملف سيكون اسمه: google-services.json

**الخطوة 5:** وضع الملف

انقل الملف إلى:
```
E:\app\delwaqty\android\app\google-services.json
```

**الخطوة 6:** أكمل في وحدة التحكم

- اضغط "Next" (تخطي تعليمات SDK)
- اضغط "Continue to console"

### الملف المطلوب

ملف واحد: `google-services.json`

ضعه في: `android/app/google-services.json`

### ملاحظة أمنية

الملف يحتوي فقط على مفاتيح عامة. آمن في مستودع خاص.

### الوقت المقدر: 10 دقائق

### الصعوبة: سهل

### هل يحتاج دفع؟ لا

### هل يحتاج بطاقة دفع؟ لا

---
---

# ACTION 3: Enable Google Maps API Key

## English

### What is this?

Google Maps API key enables map rendering, directions, nearby search, geocoding, and driver tracking in the Delwaqty app.

### Why is this required?

Without this:
- No map display
- No directions/routes
- No nearby merchant discovery
- No driver tracking
- No geocoding (address lookup)

### What happens after?

I will automatically:
1. Wire the API key into the Maps configuration
2. Enable real Google Maps rendering
3. Enable Places API for merchant search
4. Enable Directions API for routing
5. Enable Geocoding API for address lookup

### Step-by-step instructions

**Step 1:** Open Google Cloud Console

https://console.cloud.google.com

Select or create a billing account.

**Step 2:** Create a new project (or use existing)

- Project name: **"Delwaqty"**
- Click **"Create"**

**Step 3:** Enable required APIs

Go to: **APIs & Services → Library**

Enable these APIs (click each, then click "Enable"):

1. **Maps SDK for Android**
   - Search: "Maps SDK for Android"
   - Enable it

2. **Maps SDK for iOS** (for future)
   - Search: "Maps SDK for iOS"
   - Enable it

3. **Directions API**
   - Search: "Directions API"
   - Enable it

4. **Places API**
   - Search: "Places API"
   - Enable it

5. **Geocoding API**
   - Search: "Geocoding API"
   - Enable it

6. **Distance Matrix API**
   - Search: "Distance Matrix API"
   - Enable it

**Step 4:** Create API Key

- Go to: **APIs & Services → Credentials**
- Click **"+ Create Credentials"** → **"API key"**
- Copy the generated key

**Step 5:** Restrict the API key (recommended)

- Click on the new API key
- Under "Application restrictions":
  - Select **"Android apps"**
  - Click **"+ Add package name"**
  - Add: `com.example.delwaqty`
- Under "API restrictions":
  - Select **"Restrict key"**
  - Enable only the 6 APIs listed above
- Click **"Save"**

### File that will be modified

| File | Change |
|------|--------|
| `lib/config/maps_config.dart` | API key passed via `--dart-define` |
| `lib/config/maps_config_v2.dart` | API key configuration |

### How to pass the key

When building or running:
```powershell
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

Or add to `.env.dev`:
```
GOOGLE_MAPS_API_KEY=your_key_here
```

### Free tier limits

- $200/month free credit (covers ~28,000 map loads)
- Directions: 40,000 requests/month free
- Places: 11,000 requests/month free
- More than sufficient for launch

### Billing note

Google requires a billing account but you won't be charged until you exceed the free tier.

### Time: 15 minutes

### Difficulty: Medium

### Billing: Required (but free tier covers launch)

### Payment required: Credit card for verification, won't be charged

---

## بالعربي (Arabic)

### ما هذا؟

مفتاح Google Maps API يفعّل عرض الخرائط، الاتجاهات، البحث عن الأماكن القريبة، تحديد الموقع، وتتبع السائقين.

### لماذا هذا مطلوب؟

بدون هذا:
- لا عرض خرائط
- لا اتجاهات أو طرق
- لا اكتشاف تجار قريبين
- لا تتبع سائقين
- لا تحويل عنوان

### خطوات التنفيذ

**الخطوة 1:** افتح Google Cloud Console

https://console.cloud.google.com

**الخطوة 2:** أنشئ مشروع جديد

اسم المشروع: "Delwaqty"

**الخطوة 3:** فعّل APIs المطلوبة

اذهب إلى: APIs & Services → Library

فعّل هذه الـ APIs (ابحث عن كل واحد واضغط Enable):

1. Maps SDK for Android
2. Maps SDK for iOS
3. Directions API
4. Places API
5. Geocoding API
6. Distance Matrix API

**الخطوة 4:** أنشئ مفتاح API

- اذهب إلى: APIs & Services → Credentials
- اضغط "+ Create Credentials" → "API key"
- انسخ المفتاح

**الخطوة 5:** حدد صلاحيات المفتاح (مهم)

- اضغط على المفتاح الجديد
- تحت "Application restrictions": اختر "Android apps"
- أضف اسم الحزمة: `com.example.delwaqty`
- تحت "API restrictions": اختر "Restrict key"
- فعّل فقط الـ 6 APIs المذكورة أعلاه
- اضغط "Save"

### الملف المطلوب

مفتاح واحد يُمرر عبر `--dart-define`

### ملاحظة الفوترة

Google يطلب حساب فواتير لكن لن تُدفع أي شيء حتى تتجاوز الحصة المجانية.

### الوقت المقدر: 15 دقائق

### الصعوبة: متوسطة

### هل يحتاج دفع؟ حساب فواتير مطلوب (لكن الحصة المجانية كافية)

---
---

# ACTION 4: Configure Cloudflare R2

## English

### What is this?

Cloudflare R2 provides cloud storage for images (product photos, user avatars, documents) with a global CDN for fast delivery.

### Why is this required?

Without this:
- No image uploads
- No product photos
- No user avatars
- No document storage

### What happens after?

I will automatically:
1. Configure the R2 service with real credentials
2. Enable image upload via S3-compatible API
3. Enable CDN delivery URLs
4. Replace mock image service with real R2 implementation

### Step-by-step instructions

**Step 1:** Create Cloudflare account

https://dash.cloudflare.com/sign-up

- Enter email and password
- Click **"Create account"**
- Free plan is sufficient

**Step 2:** Enable R2

- Left sidebar → click **"R2"**
- Click **"Enable R2"** (no credit card required)

**Step 3:** Create a bucket

- Click **"Create bucket"**
- Bucket name: **"delwaqty-assets"**
- Location: **"Automatic"**
- Click **"Create bucket"**

**Step 4:** Create API token

- Go to **"Manage R2 API Tokens"**
- Click **"Create API token"**
- Token name: **"delwaqty-server"**
- Permissions: **"Object Read & Write"**
- Bucket: Select **"delwaqty-assets"**
- Click **"Create API Token"**
- **COPY THESE VALUES IMMEDIATELY** (they won't be shown again):
  - Access Key ID
  - Secret Access Key

**Step 5:** Get Account ID

- Go to **"R2"** → **"Overview"**
- Your **Account ID** is shown on the right side
- Copy it

### Files that will be modified

| File | Change |
|------|--------|
| `lib/config/cloudflare_config.dart` | Real R2 credentials |
| `lib/services/storage/cloudflare_r2_service.dart` | Connect to real R2 |

### Credentials generated

| Credential | Purpose | Example format |
|------------|---------|----------------|
| Account ID | Cloudflare account identifier | `abc123def456` |
| Access Key ID | R2 API authentication | `AKIAIOSFODNN7EXAMPLE` |
| Secret Access Key | R2 API secret | `wJalrXUtnFEMI/K7MDENG/...` |

### Free tier limits

- 10GB storage free
- 1,000,000 Class A requests/month (writes)
- 10,000,000 Class B requests/month (reads)
- No egress fees (unlike AWS S3)
- More than sufficient for launch

### Security note

Store credentials in `.env.dev` only. Never commit to git.

### Time: 10 minutes

### Difficulty: Medium

### Billing: No (free plan)

### Payment required: No

---

## بالعربي (Arabic)

### ما هذا؟

Cloudflare R2 هو تخزين سحابي للصور (صور المنتجات، صور المستخدمين، المستندات) مع شبكة CDN عالمية للتسليم السريع.

### لماذا هذا مطلوب؟

بدون هذا:
- لا رفع صور
- لا صور منتجات
- لا صور مستخدمين
- لا تخزين مستندات

### خطوات التنفيذ

**الخطوة 1:** أنشئ حساب Cloudflare

https://dash.cloudflare.com/sign-up

- أدخل البريد الإلكتروني وكلمة المرور
- اضغط "Create account"
- الخطة المجانية كافية

**الخطوة 2:** فعّل R2

- الشريط الجانبي → اضغط "R2"
- اضغط "Enable R2" (لا يحتاج بطاقة ائتمان)

**الخطوة 3:** أنشئ bucket (حاوية)

- اضغط "Create bucket"
- اسم الحاوية: "delwaqty-assets"
- الموقع: "Automatic"
- اضغط "Create bucket"

**الخطوة 4:** أنشئ API token

- اذهب إلى "Manage R2 API Tokens"
- اضغط "Create API token"
- اسم التوكن: "delwaqty-server"
- الصلاحيات: "Object Read & Write"
- الحاوية: اختر "delwaqty-assets"
- اضغط "Create API Token"
- **انسخ هذه القيم فوراً** (لن تظهر مرة أخرى):
  - Access Key ID
  - Secret Access Key

**الخطوة 5:** احصل على Account ID

- اذهب إلى "R2" → "Overview"
- Account ID يظهر على اليمين
- انسخه

### الملف المطلوب

ملف واحد: `.env.dev` مع بيانات R2

### ملاحظة أمنية

خزّن المفاتيح في `.env.dev` فقط. لا ترفعها إلى git أبداً.

### الوقت المقدر: 10 دقائق

### الصعوبة: متوسطة

### هل يحتاج دفع؟ لا

### هل يحتاج بطاقة دفع؟ لا

---
---

# Verification After All Actions

Once you complete all 4 actions, provide me with:

1. **Supabase**: Confirm the SQL script ran successfully
2. **Firebase**: Place `google-services.json` in `android/app/`
3. **Google Maps**: Provide the API key (or confirm it's in `.env.dev`)
4. **Cloudflare**: Provide Account ID, Access Key ID, and Secret Access Key in `.env.dev`

### What I will do automatically

1. Verify all Supabase tables and policies
2. Wire Firebase initialization with real project
3. Configure Maps with real API key
4. Configure R2 with real credentials
5. Replace ALL mock repositories
6. Delete ALL obsolete mock code
7. Build and verify the first end-to-end production flow
8. Run the full quality gate
9. Commit and push

### Expected result

A fully connected production platform with:
- Real user registration and login
- Real database storage
- Real push notifications
- Real crash reporting
- Real map rendering
- Real image storage

---

# بالعربي - ملخص

## ماذا تحتاج لفعله؟

1. **Supabase**: افتح SQL Editor والصق السكريبت (5 دقائق)
2. **Firebase**: أنشئ مشروع وحمّل ملف google-services.json (10 دقائق)
3. **Google Maps**: أنشئ مفتاح API وافعّل 6 APIs (15 دقائق)
4. **Cloudflare**: أنشئ حساب وحاوية R2 وتوكن (10 دقائق)

**المجموع: حوالي 40 دقيقة**

## هل يحتاج دفع؟

لا. جميع الخدمات لها خطة مجانية كافية للإطلاق.

## هل يحتاج بطاقة ائتمان؟

فقط Google Cloud يطلب بطاقة للتحقق (لن تُدفع أي شيء حتى الحصة المجانية $200/شهر).

## ماذا يحدث بعد؟

سأقوم تلقائياً بربط كل شيء واستبدال كل الكود الوهمي بالكود الحقيقي.

---
