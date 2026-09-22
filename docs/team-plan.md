# Team Plan — شريط واحد متحرك لكل خدمات التطبيق

## الهدف
في تطبيق العميل (`lib/features/customer/home/presentation/pages/home_page.dart`):
- يوجد حاليًا **شريطان**: `_CompactCategories` (العلوي: فئات تجارية + 4 أزرار حجز بعد صيدلية + عرض الكل) و`_ServicesSection` (السفلي: بقية أزرار الخدمات).
- المطلوب من المستخدم: **شريط واحد متحرك فقط** يعرض **كل خدمات التطبيق** (الفئات التجارية بالترتيب + كل أزرار الخدمات بالترتيب)، وفي **نهايته زر «عرض الكل»** يفتح صفحة كل الخدمات (`/services` → `AllServicesPage` الموجودة).
- `_ServicesSection` السفلي يُحذف نهائيًا (أزراره تظهر في صفحة «عرض الكل» فقط).
- الشريط يتحرك تلقائيًا **بحركة بطيئة لا نهائية** (marquee) ما لم يلمسه العميل (يوقفها اللمس/السحب ثم يستأنف).

## الملفات المملوكة
- `lib/features/customer/home/presentation/pages/home_page.dart` (الملف الوحيد)
- `docs/team-plan.md` (هذا الملف)
- `SESSION_STATUS.md` (تحديث لاحق من المنسق)

## المهمة (Task 1) — coder وحيد (ملف واحد)
**اسم المهمة:** دمج كل الخدمات في شريط علوي واحد متحرك

**المعيار القياسي (يُحسب ناجحًا لو):**
1. لا يوجد سوى شريط علوي واحد (`_CompactCategories`) يعرض: كل الفئات التجارية (مرتبة حسب `categoryRank`) + كل أزرار الخدمات (مرتبة حسب أولوية `_homeServiceCategoriesProvider` التي تبدأ doctor/nurse/teacher/barber) + زر «عرض الكل» في النهاية.
2. `_ServicesSection` محذوف من الصفحة ومن الكود (لا شريط سفلي، لا تكرار).
3. الشريط يتحرك تلقائيًا بسرعة بطيئة (~40px/s) بحلقة لا نهائية سلسة (تتوقف عند اللمس/السحب وتستأنف بعده).
4. «عرض الكل» يفتح `/services` (AllServicesPage موجودة فعليًا تعرض كل الخدمات في صفحة واحدة — لا تغيير عليها).
5. `flutter analyze` = 0 مشاكل، `flutter test` أخضر كامل.

## التفاصيل التنفيذية (لكودر2)
- أضف ويدجت خاص `_InfiniteStrip` (StatefulWidget مع `SingleTickerProviderStateMixin`) داخل home_page.dart:
  - `ScrollController` + `Ticker` (`createTicker`) بدل Timer (آمن للاختبارات).
  - المحتوى: Row = نسختان متطابقتان من التايلات (كل نسخة = تايل + `SizedBox(width: 12)` في النهاية) للالتفاف السلس.
  - قِس عرض النسخة الواحدة بعد أول إطار بـ `GlobalKey` (`addPostFrameCallback` → `RenderBox.size.width`) في `_cycleWidth`.
  - في `_onTick`: احسب `dt` من `elapsed` (اقطعه عند 0.25s)، `offset = (scroll.offset + speed * dt) % _cycleWidth`، ثم `scroll.jumpTo(offset)`.
  - إيقاف مؤقت: `Listener(onPointerDown/Up/Cancel)` يضبط `_interacting`؛ واقفز في `_onTick` إذا `_interacting || scroll.position.isScrolling || _cycleWidth <= 0`.
  - احترم تقليل الحركة: إن `MediaQuery.disableAnimationsOf(context)` فعرض نسخة واحدة فقط بدون Ticker (تمرير يدوي فقط).
  - `dispose`: ألغِ Ticker وScrollController.
- أعد بناء `_CompactCategories`:
  - شاهد providerين معًا: `activeCategoriesProvider` و`_homeServiceCategoriesProvider`.
  - اجمع النتائج: categories محسوبة بـ `categoryRank` (كلها، لا `sublist`/`visibleCount` كما الآن — احذف منطق صيدلية/`pharmacyFound`/`showAllTile` بالكامل) + services (بترتيب provider) + `_TopStripShowAll()` في النهاية دائمًا.
  - لعرضها مرّر `items` عبر الماركي (`_InfiniteStrip`) بنفس دالة `_buildStrip` الحالية (تُعيد الآن `_InfiniteStrip` بدل ListView).
  - الحالات: `loading` = shimmer كما هو؛ `error` على أي من الاثنين أو `categories.isEmpty` = `_buildStrip([..._topBookingItems, const _TopStripShowAll()])` (الاحتياط قائم: نقاط الدخول لا تختفي).
- `_homeServiceCategoriesProvider`: أعد `priority` لتشمل doctor/nurse/teacher/barber أولًا (مثل all_services_page) حتى تظهر الأزرار الأربعة أولًا بين الخدمات.
- احذف `_ServicesSection` بالكامل من slivers ومن الكود، واحذف `_movedToTop` (أصبح غير مستخدم).
- التزم AGENTS: single quotes، trailing commas، لا تعليقات جديدة غير مطلوبة، لا تلمس ملفات أخرى.

## الاعتماديات
- مهمة واحدة على ملف واحد — لا توازٍ.
- بعد التنفيذ: `flutter analyze` + `flutter test` ثم تثبيت APK على الجهاز والتحقق البصري.

## الترتيب
1. DISPATCH → coder2 ينفّذ Task 1.
2. REVIEW → فحص الـ diff.
3. FIX LOOP إن لزم (حد أقصى 3 جولات).
4. TEST → `flutter analyze` + `flutter test` (933) + build APK debug customer.
5. QA → APPROVE/REJECT.
6. تثبيت APK على الجهاز + REPORT + تحديث SESSION_STATUS.md.