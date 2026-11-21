-- 203: Pharmacy drug catalog + one-tap stocking.
-- Mission item: pharmacies signing up should find real drug products ready.
-- products is merchant-scoped, so a shared master catalog (drug_catalog)
-- holds the drugs; pharmacy_import_drug() copies an entry into the calling
-- pharmacy's own products with its price/stock. Barcodes/SKUs are optional
-- and never fabricated.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS barcode text,
  ADD COLUMN IF NOT EXISTS sku text;

CREATE TABLE IF NOT EXISTS public.drug_catalog (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name_en text NOT NULL,
  name_ar text,
  active_ingredient text,
  dosage_form text,
  strength text,
  category text,
  barcode text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (name_en, strength, dosage_form)
);

ALTER TABLE public.drug_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS drug_catalog_read ON public.drug_catalog;
CREATE POLICY drug_catalog_read ON public.drug_catalog
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS drug_catalog_admin ON public.drug_catalog;
CREATE POLICY drug_catalog_admin ON public.drug_catalog
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Copy a catalog drug into the caller's own store as a sellable product.
-- Server-checked: the merchant must belong to the caller (or admin).
CREATE OR REPLACE FUNCTION public.pharmacy_import_drug(
  p_drug_id uuid,
  p_merchant_id uuid,
  p_price numeric,
  p_stock int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_merchant public.merchants%ROWTYPE;
  v_drug public.drug_catalog%ROWTYPE;
  v_product_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_price IS NULL OR p_price < 0 THEN
    RAISE EXCEPTION 'INVALID_PRICE';
  END IF;
  IF p_stock IS NULL OR p_stock < 0 THEN
    RAISE EXCEPTION 'INVALID_STOCK';
  END IF;

  SELECT * INTO v_merchant FROM public.merchants WHERE id = p_merchant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'MERCHANT_NOT_FOUND';
  END IF;
  IF v_merchant.owner_user_id <> v_uid AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'NOT_YOUR_STORE';
  END IF;

  SELECT * INTO v_drug FROM public.drug_catalog
    WHERE id = p_drug_id AND is_active;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'DRUG_NOT_FOUND';
  END IF;

  INSERT INTO public.products (
    merchant_id, name, name_ar, description, description_ar, price,
    category, stock_quantity, is_available, barcode
  ) VALUES (
    p_merchant_id,
    v_drug.name_en || COALESCE(' ' || v_drug.strength, ''),
    v_drug.name_ar,
    concat_ws(' · ', v_drug.active_ingredient, v_drug.strength, v_drug.dosage_form),
    v_drug.name_ar,
    p_price,
    'pharmacy',
    p_stock,
    true,
    v_drug.barcode
  )
  RETURNING id INTO v_product_id;

  RETURN jsonb_build_object('ok', true, 'product_id', v_product_id);
END;
$function$;

-- Starter catalog: common medications on the Egyptian market (brand names,
-- ingredients and strengths as sold). No prices or barcodes are invented.
INSERT INTO public.drug_catalog (name_en, name_ar, active_ingredient, dosage_form, strength, category) VALUES
  ('Panadol', 'بانادول', 'Paracetamol', 'tablets', '500 mg', 'pain_fever'),
  ('Panadol Extra', 'بانادول إكسترا', 'Paracetamol + Caffeine', 'tablets', '500 mg / 65 mg', 'pain_fever'),
  ('Panadol Cold & Flu', 'بانادول كولد آند فلو', 'Paracetamol + Pseudoephedrine + Chlorpheniramine', 'tablets', '500/30/2 mg', 'cold_flu'),
  ('Brufen', 'بروفين', 'Ibuprofen', 'tablets', '400 mg', 'pain_fever'),
  ('Brufen Syrup', 'بروفين شراب', 'Ibuprofen', 'syrup', '100 mg/5 ml', 'pain_fever'),
  ('Cataflam', 'كتافلام', 'Diclofenac potassium', 'tablets', '50 mg', 'pain_fever'),
  ('Catafast', 'كتافاست', 'Diclofenac potassium', 'sachets', '50 mg', 'pain_fever'),
  ('Voltaren', 'فولتارين', 'Diclofenac sodium', 'tablets', '50 mg', 'pain_fever'),
  ('Voltaren Gel', 'فولتارين جل', 'Diclofenac diethylamine', 'gel', '1.16%', 'topical'),
  ('Ketofan', 'كيتوفان', 'Ketoprofen', 'capsules', '50 mg', 'pain_fever'),
  ('Augmentin', 'أوجمنتين', 'Amoxicillin + Clavulanic acid', 'tablets', '625 mg', 'antibiotics'),
  ('Augmentin ES', 'أوجمنتين إي إس', 'Amoxicillin + Clavulanic acid', 'suspension', '600/42.9 mg per 5 ml', 'antibiotics'),
  ('Zithromax', 'زيثروماكس', 'Azithromycin', 'tablets', '500 mg', 'antibiotics'),
  ('Zisrocin', 'زيسروسين', 'Azithromycin', 'tablets', '500 mg', 'antibiotics'),
  ('Klacid', 'كلاسيد', 'Clarithromycin', 'tablets', '500 mg', 'antibiotics'),
  ('Ciprobay', 'سيبروباي', 'Ciprofloxacin', 'tablets', '500 mg', 'antibiotics'),
  ('Suprax', 'سوبراكس', 'Cefixime', 'capsules', '400 mg', 'antibiotics'),
  ('Vibramycin', 'فيبراميسين', 'Doxycycline', 'capsules', '100 mg', 'antibiotics'),
  ('Flagyl', 'فلاجيل', 'Metronidazole', 'tablets', '500 mg', 'antibiotics'),
  ('Nexium', 'نيكسيوم', 'Esomeprazole', 'tablets', '40 mg', 'gastro'),
  ('Controloc', 'كونترولوك', 'Pantoprazole', 'tablets', '40 mg', 'gastro'),
  ('Gaviscon', 'جافيسكون', 'Sodium alginate + antacids', 'suspension', '500 mg/10 ml', 'gastro'),
  ('Motilium', 'موتيليوم', 'Domperidone', 'tablets', '10 mg', 'gastro'),
  ('Buscopan', 'بوسكوبان', 'Hyoscine butylbromide', 'tablets', '10 mg', 'gastro'),
  ('Imodium', 'إيموديوم', 'Loperamide', 'capsules', '2 mg', 'gastro'),
  ('Dulcolax', 'دلكولاكس', 'Bisacodyl', 'tablets', '5 mg', 'gastro'),
  ('Duphalac', 'ديوفلاك', 'Lactulose', 'syrup', '667 mg/ml', 'gastro'),
  ('Zyrtec', 'زيرتك', 'Cetirizine', 'tablets', '10 mg', 'allergy'),
  ('Claritine', 'كلاريتين', 'Loratadine', 'tablets', '10 mg', 'allergy'),
  ('Telfast', 'تلفاست', 'Fexofenadine', 'tablets', '180 mg', 'allergy'),
  ('Fenistil Gel', 'فينيستيل جل', 'Dimetindene maleate', 'gel', '0.1%', 'allergy'),
  ('Ventolin', 'فينتولين', 'Salbutamol', 'inhaler', '100 mcg/dose', 'respiratory'),
  ('Pulmicort', 'بولميكورت', 'Budesonide', 'nebulizer suspension', '0.5 mg/ml', 'respiratory'),
  ('Glucophage', 'جلوكوفاج', 'Metformin', 'tablets', '850 mg', 'diabetes'),
  ('Amaryl', 'أمريل', 'Glimepiride', 'tablets', '2 mg', 'diabetes'),
  ('Janumet', 'جانوميت', 'Sitagliptin + Metformin', 'tablets', '50/1000 mg', 'diabetes'),
  ('Galvus Met', 'جالفس ميت', 'Vildagliptin + Metformin', 'tablets', '50/850 mg', 'diabetes'),
  ('Concor', 'كونكور', 'Bisoprolol', 'tablets', '5 mg', 'cardio'),
  ('Norvasc', 'نورفاسك', 'Amlodipine', 'tablets', '5 mg', 'cardio'),
  ('Co-Diovan', 'كو-ديوفان', 'Valsartan + Hydrochlorothiazide', 'tablets', '160/12.5 mg', 'cardio'),
  ('Capoten', 'كابوتين', 'Captopril', 'tablets', '25 mg', 'cardio'),
  ('Aspirin Protect', 'أسبرين بروتكت', 'Acetylsalicylic acid', 'tablets', '100 mg', 'cardio'),
  ('Plavix', 'بلافيكس', 'Clopidogrel', 'tablets', '75 mg', 'cardio'),
  ('Lipitor', 'ليبيتور', 'Atorvastatin', 'tablets', '20 mg', 'cardio'),
  ('Crestor', 'كريستور', 'Rosuvastatin', 'tablets', '10 mg', 'cardio'),
  ('Eltroxin', 'إلتروكسين', 'Levothyroxine', 'tablets', '100 mcg', 'thyroid'),
  ('Fucidin', 'فيوسيدين', 'Fusidic acid', 'cream', '2%', 'topical'),
  ('Betadine', 'بيتادين', 'Povidone iodine', 'solution', '10%', 'antiseptic'),
  ('Mebo', 'ميبو', 'Beta-sitosterol herbal base', 'ointment', '30 g', 'topical'),
  ('Feroglobin', 'فيروجلوبين', 'Iron + vitamins', 'capsules', 'multivitamin', 'supplements'),
  ('Ferrotron', 'فيروترون', 'Iron + Folic acid', 'capsules', 'multivitamin', 'supplements'),
  ('Osteocare', 'أوسيوكير', 'Calcium + Vitamin D + minerals', 'tablets', 'multivitamin', 'supplements'),
  ('Centrum', 'سنتروم', 'Multivitamins', 'tablets', 'multivitamin', 'supplements'),
  ('Supradyn', 'سوبرادين', 'Multivitamins + minerals', 'effervescent tablets', 'multivitamin', 'supplements'),
  ('Neurobion', 'نيوروبيون', 'Vitamins B1 + B6 + B12', 'tablets', '100/200/0.2 mg', 'supplements'),
  ('Milga', 'ميلجا', 'Vitamins B1 + B6 + B12', 'tablets', '40/90/0.25 mg', 'supplements'),
  ('Vitamin D3', 'فيتامين د3', 'Cholecalciferol', 'drops', '1000 IU/ml', 'supplements'),
  ('Panadol Baby & Infant', 'بانادول أطفال', 'Paracetamol', 'suspension', '120 mg/5 ml', 'pediatric'),
  ('Antinal', 'أنتينال', 'Nifuroxazide', 'capsules', '200 mg', 'gastro'),
  ('Strepsils', 'ستريبسلز', 'Amylmetacresol + Dichlorobenzyl alcohol', 'lozenges', '0.6/1.2 mg', 'cold_flu'),
  ('Otrivin', 'أوتريفين', 'Xylometazoline', 'nasal spray', '0.1%', 'cold_flu')
ON CONFLICT (name_en, strength, dosage_form) DO NOTHING;

NOTIFY pgrst, 'reload schema';
