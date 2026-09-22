# Team Plan — دمج أزرار الحجز في الشريط العلوي بالصفحة الرئيسية

## الهدف
في تطبيق العميل (`lib/features/customer/home/presentation/pages/home_page.dart`)، الأزرار
الجديدة (حجز دكتور، ممرض، مدرسين، حجز حلاق) موجودة حاليًا في شريط `_ServicesSection`
الأسفل (تحت قائمة الخدمات الأساسية = شريط `_CompactCategories` العلوي).
المطلوب: نقل هذه الأزرار الأربعة إلى الشريط العلوي مباشرة بعد زر «صيدلية»
وقبل زر «عرض الكل»، وإبقاؤها مع الأزرار العلوية (إزالتها من القسم السفلي حتى لا تتكرر).

## الملفات المملوكة
- `lib/features/customer/home/presentation/pages/home_page.dart` (الملف الوحيد)
- `docs/team-plan.md` (هذا الملف)
- `SESSION_STATUS.md` (تحديث لاحق من المنسق)

## المهمة (Task 1) — coder وحيد (ملف واحد، لا توازٍ)
**اسم المهمة:** دمج أزرار الحجز الأربعة في الشريط العلوي

**المعيار القياسي (يُحسب ناجحًا لو):**
1. شريط `_CompactCategories` يُظهر: الفئات التجارية المرئية ثم مباشرة بعد فئة
   `صيدلية` الأزرار الأربعة (حجز دكتور، ممرض، مدرسين، حجز حلاق) ثم زر «عرض الكل».
2. كل زر خدمة يفتح مساره الصحيح `/home-services/providers/{type.name}`.
3. أزرار الحجز الأربعة لم تعد تظهر في `_ServicesSection` (لا تكرار).
4. `flutter analyze` = 0 مشاكل، `flutter test` أخضر.

## الاعتماديات
- لا توجد مهام متوازية (ملف واحد حصري).
- بعد التنفيذ: `reviewer` يفحص الـ diff، ثم `tester` يشغّل `flutter analyze` و`flutter test`، ثم `qa` يقرر.

## الترتيب
1. DISPATCH → coder ينفّذ Task 1.
2. REVIEW → reviewer على الـ diff.
3. FIX LOOP إن لزم (حد أقصى 3 جولات).
4. TEST → tester: `flutter analyze` + `flutter test`.
5. QA → APPROVE/REJECT.
6. REPORT + تحديث SESSION_STATUS.md.