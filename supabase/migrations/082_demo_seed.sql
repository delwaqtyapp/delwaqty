-- 082_demo_seed.sql
-- Demo seed: sample providers + merchants (global across Egypt) so every
-- service page shows data. Replace/remove before production (or keep as a
-- starting catalog the owner edits). Photos are placeholders from the web.

-- 1) Seed service_providers no longer requires a real auth user
ALTER TABLE service_providers ALTER COLUMN user_id DROP NOT NULL;

-- 2) Widen merchants.type to include the new category types
ALTER TABLE merchants DROP CONSTRAINT IF EXISTS merchants_type_check;
ALTER TABLE merchants ADD CONSTRAINT merchants_type_check CHECK (type IN (
  'food','restaurant','grocery','supermarket','pharmacy','electronics','fashion','flowers','bakery',
  'general','fruits','meat','seafood','sweets','clothing','shoes','mobile','furniture','home','cafe',
  'petShop','fitness','gas','carwash','perfumes','spices','dairy','accessories','butcher','vegetables','other'));

-- 3) Seed service providers (doctors, nurses, teachers, barbers, home services)
INSERT INTO service_providers
  (name, category_type, description, profile_image_url, rating, rating_count, is_verified, is_available,
   hourly_rate, fixed_price_min, fixed_price_max, city, latitude, longitude, tags)
VALUES
  ('د. أحمد حسن','doctor','طب عام واستشارات','https://randomuser.me/api/portraits/women/1.jpg',4.2,19,true,true,250.00,NULL,NULL,'Cairo',30.052766,31.207201,ARRAY['doctor']),
  ('د. منى السيد','doctor','أمراض القلب','https://randomuser.me/api/portraits/men/2.jpg',4.7,39,true,true,400.00,NULL,NULL,'Giza',29.991472,31.18505,ARRAY['doctor']),
  ('د. خالد محمود','doctor','طب الأطفال','https://randomuser.me/api/portraits/women/3.jpg',4.0,18,true,true,300.00,NULL,NULL,'Alexandria',31.175316,29.914015,ARRAY['doctor']),
  ('د. سارة إبراهيم','doctor','نساء وتوليد','https://randomuser.me/api/portraits/men/4.jpg',4.5,39,true,true,450.00,NULL,NULL,'Mansoura',31.02486,31.384621,ARRAY['doctor']),
  ('د. عمر فاروق','doctor','أمراض جلدية','https://randomuser.me/api/portraits/women/5.jpg',4.3,5,true,true,350.00,NULL,NULL,'Tanta',30.783671,30.998853,ARRAY['doctor']),
  ('د. نور أحمد','doctor','جراحة عظام','https://randomuser.me/api/portraits/men/6.jpg',4.4,22,true,true,500.00,NULL,NULL,'Aswan',24.104428,32.87938,ARRAY['doctor']),
  ('ممرضة فاطمة علي','nurse','رعاية منزلية وحقن','https://randomuser.me/api/portraits/women/7.jpg',4.3,10,true,true,120.00,NULL,NULL,'Luxor',25.666529,32.667033,ARRAY['nurse']),
  ('محمد سمير','nurse','تمريض منزلي','https://randomuser.me/api/portraits/men/8.jpg',4.3,21,true,true,110.00,NULL,NULL,'Port Said',31.258096,32.293439,ARRAY['nurse']),
  ('آية مصطفى','nurse','حقن وضمادات','https://randomuser.me/api/portraits/women/9.jpg',4.5,29,true,true,100.00,NULL,NULL,'Zagazig',30.606128,31.515784,ARRAY['nurse']),
  ('حسام الدين','nurse','رعاية مسنين','https://randomuser.me/api/portraits/men/10.jpg',4.6,28,true,true,130.00,NULL,NULL,'Minya',28.084628,30.737891,ARRAY['nurse']),
  ('رانيا كامل','nurse','تمريض منزلي','https://randomuser.me/api/portraits/women/11.jpg',4.0,19,true,true,115.00,NULL,NULL,'Cairo',30.049041,31.247974,ARRAY['nurse']),
  ('أ. محمد عادل','teacher','مدرس رياضيات','https://randomuser.me/api/portraits/men/12.jpg',4.8,11,true,true,150.00,NULL,NULL,'Giza',30.029484,31.238013,ARRAY['teacher']),
  ('أ. هالة مصطفى','teacher','مدرس لغة إنجليزية','https://randomuser.me/api/portraits/women/13.jpg',4.8,15,true,true,140.00,NULL,NULL,'Alexandria',31.192908,29.915905,ARRAY['teacher']),
  ('أ. أحمد طارق','teacher','مدرس فيزياء','https://randomuser.me/api/portraits/men/14.jpg',4.2,9,true,true,160.00,NULL,NULL,'Mansoura',31.033111,31.36107,ARRAY['teacher']),
  ('أ. نرمين سامي','teacher','مدرسة لغة عربية','https://randomuser.me/api/portraits/women/15.jpg',4.7,15,true,true,130.00,NULL,NULL,'Tanta',30.795048,30.982168,ARRAY['teacher']),
  ('أ. كريم حسن','teacher','مدرس كيمياء','https://randomuser.me/api/portraits/men/16.jpg',4.8,40,true,true,155.00,NULL,NULL,'Aswan',24.086636,32.885997,ARRAY['teacher']),
  ('صالون النور','barber','حلاقة عصرية','https://randomuser.me/api/portraits/women/17.jpg',4.7,8,true,true,NULL,100.00,NULL,'Luxor',25.670377,32.629057,ARRAY['barber']),
  ('حلاقة الجمال','barber','حلاقة كلاسيكية','https://randomuser.me/api/portraits/men/18.jpg',4.3,22,true,true,NULL,80.00,NULL,'Port Said',31.249043,32.273826,ARRAY['barber']),
  ('صالون الأمير','barber','حلاقة وترتيب','https://randomuser.me/api/portraits/women/19.jpg',4.5,25,true,true,NULL,120.00,NULL,'Zagazig',30.561671,31.526788,ARRAY['barber']),
  ('حلاقة الشباب','barber','حلاقة عصرية','https://randomuser.me/api/portraits/men/20.jpg',4.8,34,true,true,NULL,90.00,NULL,'Minya',28.092658,30.750254,ARRAY['barber']),
  ('صالون الفارس','barber','حلاقة وبربري','https://randomuser.me/api/portraits/women/21.jpg',4.7,39,true,true,NULL,130.00,NULL,'Cairo',30.022972,31.214078,ARRAY['barber']),
  ('سباك المنزل','plumbing','إصلاح تسريبات وتركيب','https://randomuser.me/api/portraits/men/22.jpg',4.8,30,true,true,100.00,NULL,NULL,'Giza',29.998864,31.213975,ARRAY['plumbing']),
  ('مؤسسة النيل للسباكة','plumbing','سباكة كاملة','https://randomuser.me/api/portraits/women/23.jpg',4.1,36,true,true,120.00,NULL,NULL,'Alexandria',31.19182,29.94854,ARRAY['plumbing']),
  ('فني سباكة أيمن','plumbing','إصلاح وصيانة','https://randomuser.me/api/portraits/men/24.jpg',4.1,15,true,true,90.00,NULL,NULL,'Mansoura',31.016355,31.351327,ARRAY['plumbing']),
  ('سباكة القاهرة','plumbing','تركيب وإصلاح','https://randomuser.me/api/portraits/women/25.jpg',4.1,29,true,true,110.00,NULL,NULL,'Tanta',30.806025,30.99723,ARRAY['plumbing']),
  ('فني محمود','plumbing','سباكة منزلية','https://randomuser.me/api/portraits/men/26.jpg',4.2,40,true,true,85.00,NULL,NULL,'Aswan',24.094653,32.897883,ARRAY['plumbing']),
  ('كهربائي حاتم','electrical','تمديدات وإصلاح كهرباء','https://randomuser.me/api/portraits/women/27.jpg',4.6,39,true,true,100.00,NULL,NULL,'Luxor',25.708847,32.610289,ARRAY['electrical']),
  ('مؤسسة الأمان للكهرباء','electrical','كهرباء منزلية','https://randomuser.me/api/portraits/men/28.jpg',4.3,23,true,true,120.00,NULL,NULL,'Port Said',31.280353,32.318016,ARRAY['electrical']),
  ('فني كهرباء سامي','electrical','إصلاح أعطال','https://randomuser.me/api/portraits/women/29.jpg',4.9,21,true,true,95.00,NULL,NULL,'Zagazig',30.583786,31.499223,ARRAY['electrical']),
  ('كهرباء المستقبل','electrical','تمديدات','https://randomuser.me/api/portraits/men/30.jpg',4.5,11,true,true,110.00,NULL,NULL,'Minya',28.138213,30.766018,ARRAY['electrical']),
  ('فني محمد','electrical','كهرباء وتكييف','https://randomuser.me/api/portraits/women/31.jpg',4.6,17,true,true,105.00,NULL,NULL,'Cairo',30.066631,31.223607,ARRAY['electrical']),
  ('نجار الخير','carpentry','تركيب أثاث','https://randomuser.me/api/portraits/men/32.jpg',4.5,38,true,true,130.00,NULL,NULL,'Giza',29.99227,31.224651,ARRAY['carpentry']),
  ('مؤسسة النجارين','carpentry','أعمال نجارة','https://randomuser.me/api/portraits/women/33.jpg',4.4,12,true,true,140.00,NULL,NULL,'Alexandria',31.22521,29.924637,ARRAY['carpentry']),
  ('نجار كريم','carpentry','تفصيل وتركيب','https://randomuser.me/api/portraits/men/34.jpg',4.7,24,true,true,120.00,NULL,NULL,'Mansoura',31.066646,31.401223,ARRAY['carpentry']),
  ('نجارة الأمان','carpentry','إصلاح أثاث','https://randomuser.me/api/portraits/women/35.jpg',4.5,10,true,true,110.00,NULL,NULL,'Tanta',30.772867,30.986352,ARRAY['carpentry']),
  ('فني نجارة وليد','carpentry','تركيب مطابخ','https://randomuser.me/api/portraits/men/36.jpg',4.1,39,true,true,150.00,NULL,NULL,'Aswan',24.064039,32.898959,ARRAY['carpentry']),
  ('خدمة نظافة المنزل','cleaning','تنظيف شامل','https://randomuser.me/api/portraits/women/37.jpg',4.4,40,true,true,NULL,200.00,NULL,'Luxor',25.70315,32.617303,ARRAY['cleaning']),
  ('شركة النظافة المتميزة','cleaning','تنظيف مكاتب ومنازل','https://randomuser.me/api/portraits/men/38.jpg',4.5,18,true,true,NULL,250.00,NULL,'Port Said',31.245208,32.30356,ARRAY['cleaning']),
  ('مغسلة وخدمة تنظيف','cleaning','تنظيف عميق','https://randomuser.me/api/portraits/women/39.jpg',4.6,24,true,true,NULL,180.00,NULL,'Zagazig',30.613435,31.517316,ARRAY['cleaning']),
  ('نظافة بلا حدود','cleaning','تنظيف أسبوعي','https://randomuser.me/api/portraits/men/40.jpg',4.3,38,true,true,NULL,160.00,NULL,'Minya',28.10384,30.760601,ARRAY['cleaning']),
  ('خدمة تنظيف السيد','cleaning','تنظيف منازل','https://randomuser.me/api/portraits/women/41.jpg',4.1,6,true,true,NULL,190.00,NULL,'Cairo',30.041489,31.220574,ARRAY['cleaning'])
ON CONFLICT (id) DO NOTHING;

-- 4) Seed merchants (butcher, restaurants, grocery, pharmacy)
INSERT INTO merchants
  (name, type, status, description, logo_url, cover_url, phone, address, latitude, longitude,
   rating, total_reviews, total_orders, delivery_fee, min_order, delivery_time_min, is_featured)
VALUES
  ('جزارة الخير','butcher','active','لحوم طازجة','https://picsum.photos/seed/m0/400/300','https://picsum.photos/seed/mc0/900/400','011000000','Cairo',30.052766,31.207201,4.2,38,121,26.00,58.00,54,true),
  ('جزارة الأمان','butcher','active','لحوم بلدي','https://picsum.photos/seed/m1/400/300','https://picsum.photos/seed/mc1/900/400','011100000','Giza',29.988316,31.204215,4.0,37,169,52.00,53.00,21,true),
  ('جزارة النور','butcher','active','لحوم طازجة يومياً','https://picsum.photos/seed/m2/400/300','https://picsum.photos/seed/mc2/900/400','011200000','Alexandria',31.203775,29.931661,4.6,63,162,48.00,52.00,37,true),
  ('جزارة الفتح','butcher','active','لحوم وكبدة','https://picsum.photos/seed/m3/400/300','https://picsum.photos/seed/mc3/900/400','011300000','Mansoura',31.059466,31.34889,4.6,64,224,37.00,24.00,33,true),
  ('جزارة العز','butcher','active','لحوم حمراء ممتازة','https://picsum.photos/seed/m4/400/300','https://picsum.photos/seed/mc4/900/400','011400000','Tanta',30.815933,30.992096,4.1,22,233,42.00,53.00,36,true),
  ('مطعم الذواقة','restaurant','active','مأكولات شرقية','https://picsum.photos/seed/m5/400/300','https://picsum.photos/seed/mc5/900/400','011500000','Aswan',24.107328,32.913584,4.4,58,90,55.00,33.00,60,true),
  ('مطعم النيل','restaurant','active','أكلات مصرية','https://picsum.photos/seed/m6/400/300','https://picsum.photos/seed/mc6/900/400','011600000','Luxor',25.694311,32.661302,4.5,18,73,34.00,33.00,25,true),
  ('مطعم البيتزا','restaurant','active','بيتزا إيطالي','https://picsum.photos/seed/m7/400/300','https://picsum.photos/seed/mc7/900/400','011700000','Port Said',31.286619,32.323889,4.3,68,375,43.00,25.00,43,true),
  ('مطعم المشويات','restaurant','active','مشويات','https://picsum.photos/seed/m8/400/300','https://picsum.photos/seed/mc8/900/400','011000000','Zagazig',30.579016,31.512211,4.6,19,361,60.00,25.00,54,true),
  ('مطعم الكشري','restaurant','active','كشري مصري','https://picsum.photos/seed/m9/400/300','https://picsum.photos/seed/mc9/900/400','011100000','Minya',28.123648,30.730104,4.3,38,400,40.00,18.00,34,true),
  ('بقالة السوق','grocery','active','بقالة ومواد غذائية','https://picsum.photos/seed/m10/400/300','https://picsum.photos/seed/mc10/900/400','011200000','Cairo',30.063708,31.254003,4.3,18,158,56.00,60.00,40,true),
  ('بقالة العائلة','grocery','active','مواد غذائية','https://picsum.photos/seed/m11/400/300','https://picsum.photos/seed/mc11/900/400','011300000','Giza',29.995858,31.208854,4.7,68,123,36.00,23.00,35,true),
  ('بقالة الخير','grocery','active','سوبر ماركت صغير','https://picsum.photos/seed/m12/400/300','https://picsum.photos/seed/mc12/900/400','011400000','Alexandria',31.214799,29.921039,4.6,64,348,45.00,38.00,34,true),
  ('بقالة الأمان','grocery','active','خضار وفاكهة','https://picsum.photos/seed/m13/400/300','https://picsum.photos/seed/mc13/900/400','011500000','Mansoura',31.07074,31.3568,4.4,16,106,29.00,55.00,30,true),
  ('صيدلية الشفاء','pharmacy','active','مستلزمات طبية','https://picsum.photos/seed/m14/400/300','https://picsum.photos/seed/mc14/900/400','011600000','Tanta',30.806025,30.99723,4.1,58,355,49.00,48.00,36,true),
  ('صيدلية النور','pharmacy','active','أدوية وعناية','https://picsum.photos/seed/m15/400/300','https://picsum.photos/seed/mc15/900/400','011700000','Aswan',24.117165,32.921447,4.0,24,399,54.00,32.00,41,true),
  ('صيدلية الحياة','pharmacy','active','مستلزمات طبية','https://picsum.photos/seed/m16/400/300','https://picsum.photos/seed/mc16/900/400','011000000','Luxor',25.663893,32.635686,4.4,43,306,31.00,47.00,26,true),
  ('صيدلية الصحة','pharmacy','active','عناية شخصية','https://picsum.photos/seed/m17/400/300','https://picsum.photos/seed/mc17/900/400','011100000','Port Said',31.287531,32.289807,4.5,35,128,43.00,25.00,54,true)
ON CONFLICT (id) DO NOTHING;
