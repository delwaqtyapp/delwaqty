using System;
using System.Collections.Generic;

namespace Delwaqty.Pos.Core.Pharmacy
{
    /// <summary>
    /// Flags items whose active ingredient is on the Egyptian controlled /
    /// monitored lists (أدوية الجدول) so the cashier gets a dispensing prompt.
    /// This is a dispensing reminder only — never medical advice and never a
    /// refusal: the pharmacist decides.
    ///
    /// Matching is by normalized active ingredient (exact) or normalized
    /// product name (prefix), mirroring ArabicNormalizer rules.
    /// </summary>
    public static class ControlledSubstances
    {
        // Common Egyptian schedule/monitored active ingredients (lower-case,
        // Latin names as they appear in the MoH-aligned catalog).
        private static readonly HashSet<string> Ingredients = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "tramadol",
            "morphine",
            "codeine",
            "fentanyl",
            "oxycodone",
            "pethidine",
            "methadone",
            "buprenorphine",
            "alprazolam",
            "diazepam",
            "clonazepam",
            "lorazepam",
            "bromazepam",
            "midazolam",
            "zolpidem",
            "zopiclone",
            "phenobarbital",
            "pentobarbital",
            "pregabalin",
            "gabapentin",
            "clonidine",
            "ketamine",
            "amphetamine",
            "methylphenidate",
            "ephedrine",
            "pseudoephedrine",
        };

        /// <summary>
        /// True when the ingredient or product name indicates a controlled
        /// substance. nameOrIngredient may be the Arabic/English name or the
        /// active-ingredient string ("Tramadol HCl 50mg" matches "tramadol").
        /// Combination products are split on every usual separator
        /// ("tramadol+paracetamol", "Tramadol/Paracetamol") — review #120.
        /// </summary>
        public static bool IsControlled(string nameOrIngredient)
        {
            if (string.IsNullOrWhiteSpace(nameOrIngredient)) return false;
            var norm = Text.ArabicNormalizer.Normalize(nameOrIngredient);
            if (norm == null) return false;
            var words = norm.Split(
                new[] { ' ', '\t', '+', '/', '\\', '-', '(', ')', '[', ']', ',', ';', ':', '.', '\'', '"', '_' },
                StringSplitOptions.RemoveEmptyEntries);
            foreach (var word in words)
            {
                if (word.Length > 0 && Ingredients.Contains(word)) return true;
            }
            return false;
        }

        /// <summary>
        /// The sale-time check (#120): a null OR empty/whitespace ingredient
        /// both fall back to the display name, so catalog rows without an
        /// ingredient field are still checked by name.
        /// </summary>
        public static bool ShouldWarn(string ingredient, string fallbackName)
        {
            return IsControlled(string.IsNullOrWhiteSpace(ingredient) ? fallbackName : ingredient);
        }

        // #120: this prompt is a CONVENIENCE REMINDER for the pharmacist, not
        // a compliance gate and never medical advice; wording says so plainly.
        public const string TitleAr = "تنبيه صرف (مساعد — غير ملزم)";
        public const string WarningAr =
            "هذا الصنف قد يكون خاضعاً للرقابة (جدول). " +
            "تنبيه مساعد فقط وليس حكماً قانونياً: تحقق من الروشتة والقواعد بنفسك — القرار والمسؤولية عليك كصيدلي.";
    }
}
