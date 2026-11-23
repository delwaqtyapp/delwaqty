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
        /// </summary>
        public static bool IsControlled(string nameOrIngredient)
        {
            if (string.IsNullOrWhiteSpace(nameOrIngredient)) return false;
            var norm = Text.ArabicNormalizer.Normalize(nameOrIngredient);
            if (norm == null) return false;
            foreach (var raw in norm.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries))
            {
                // Strip surrounding punctuation: "(tramadol" from "Ultracet (Tramadol + ...)".
                var word = raw.Trim('(', ')', '[', ']', ',', ';', ':', '.', '+', '/', '-', '\'', '"');
                if (word.Length > 0 && Ingredients.Contains(word)) return true;
            }
            return false;
        }

        /// <summary>The warning the cashier sees. Dispensing prompt only.</summary>
        public const string WarningAr =
            "صنف خاضع للرقابة (جدول): تأكد من وجود روشتة سارية قبل الصرف";
    }
}
