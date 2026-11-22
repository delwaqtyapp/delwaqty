using Delwaqty.Pos.Core.Text;
using Xunit;

namespace Delwaqty.Pos.Core.Tests
{
    public class NormalizerTests
    {
        [Theory]
        // Egyptian misspelling of Contafever: ڤ folds to ف, matching the catalog row.
        [InlineData("كونتافيڤر", "كونتافيفر")]
        [InlineData("بنادول", "بنادول")]
        [InlineData("Panadol Extra", "panadol extra")]
        [InlineData("أنسولين", "انسولين")]
        [InlineData("إيبوبروفين", "ايبوبروفين")]
        [InlineData("آسبرين", "اسبرين")]
        [InlineData("أموكسيل", "اموكسيل")]
        [InlineData("بروفين٪", "بروفين٪")]          // non-diacritic chars untouched
        [InlineData("زِتْرُومَاكْس", "ز ت ر وم اك س")] // diacritic runs split like the SQL regex
        [InlineData("بنادول   اكسترا", "بنادول اكسترا")] // whitespace collapse
        [InlineData("  اوميبرازول  ", "اوميبرازول")]
        [InlineData("كريم مرطب", "كريم مرطب")]      // NBSP to space
        [InlineData("فيتامين ج", "فيتامين ج")]
        [InlineData("پانادول", "بانادول")]           // پ→ب
        [InlineData("ڤولتارين", "فولتارين")]         // ڤ→ف
        public void Mirrors_Server_Normalization(string input, string expected)
        {
            Assert.Equal(expected, ArabicNormalizer.Normalize(input));
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("   ")]
        public void Empty_Becomes_Null(string input)
        {
            Assert.Null(ArabicNormalizer.Normalize(input));
        }

        [Fact]
        public void Tatweel_And_Tanween_Collapse()
        {
            // tatweel between letters becomes one space (matches the SQL regex behavior)
            Assert.Equal("ب نادول", ArabicNormalizer.Normalize("بـنادول"));
        }
    }
}
