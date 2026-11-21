-- 086_reviews_home_labor_and_merchants.sql
-- (a) Category-level service reviews for the 8 home-labor categories that have
--     NO providers yet (pestControl, painting, dishRepair, applianceRepair,
--     carpetCleaning, pipeChange, plastering, acMaintenance) so their reviews
--     pages are reachable and NOT empty.
-- (b) One real review per remaining merchant type (pharmacy/grocery/bakery/food)
--     so those merchant pages also show live reviews.
-- user_id NULL keeps these anonymous like the existing demo seeds; the unique
-- index (user_id, category_type, provider_id) treats NULL as distinct so
-- multiple category-level anonymous seeds never conflict.

-- (a) home-labor categories ------------------------------------------------
INSERT INTO service_reviews (user_id, category_type, provider_id, user_name, rating, comment)
VALUES (NULL, 'pestControl', NULL, 'عمرو حامد', 4, 'قضى على الصراصير من أول مرة'),
       (NULL, 'painting', NULL, 'شيماء نبيل', 5, 'دهان نضيف وألوان مضبوطة'),
       (NULL, 'dishRepair', NULL, 'أيمن صبري', 4, 'صلّح البوتاجاز بسرعة'),
       (NULL, 'applianceRepair', NULL, 'هناء عادل', 5, 'الأجهزة بقت شغالة زي الجديدة'),
       (NULL, 'carpetCleaning', NULL, 'طارق فؤاد', 5, 'السجادة رجعت جديدة'),
       (NULL, 'pipeChange', NULL, 'مصطفى كمال', 4, 'غيّر المواسير في وقت قياسي'),
       (NULL, 'plastering', NULL, 'إيمان رجب', 5, 'بياض نظيف وأسعار مناسبة'),
       (NULL, 'acMaintenance', NULL, 'حسام الدين', 5, 'التكييف بقى فريش مرة تانية')
ON CONFLICT DO NOTHING;

-- (b) remaining merchant types ----------------------------------------------
INSERT INTO reviews (user_id, merchant_id, rating, comment)
SELECT NULL, id, 4, 'دواء موجود وعرض عليه صيدلي محترم'
FROM merchants WHERE type = 'pharmacy' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO reviews (user_id, merchant_id, rating, comment)
SELECT NULL, id, 4, 'بقالة كاملة والسلع طازة'
FROM merchants WHERE type = 'grocery' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO reviews (user_id, merchant_id, rating, comment)
SELECT NULL, id, 5, 'عيش طازة كل يوم والعجين ممتاز'
FROM merchants WHERE type = 'bakery' LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO reviews (user_id, merchant_id, rating, comment)
SELECT NULL, id, 4, 'أكل لذيذ والتغليف محترم'
FROM merchants WHERE type = 'food' LIMIT 1
ON CONFLICT DO NOTHING;