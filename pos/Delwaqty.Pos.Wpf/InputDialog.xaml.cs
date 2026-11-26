using System.Windows;
using System.Windows.Input;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>Small one-field prompt used for amounts, reasons and notes.</summary>
    public partial class InputDialog : Window
    {
        public string Value { get { return ValueBox.Text; } }

        public InputDialog(string title, string prompt, string initial)
        {
            InitializeComponent();
            Title = title;
            PromptText.Text = prompt;
            ValueBox.Text = initial ?? "";
            ValueBox.SelectAll();
            ValueBox.Focus();
        }

        public static string Ask(Window owner, string title, string prompt, string initial)
        {
            var d = new InputDialog(title, prompt, initial) { Owner = owner };
            return d.ShowDialog() == true ? d.Value : null;
        }

        public static decimal? AskAmount(Window owner, string title, string prompt, string initial)
        {
            var text = Ask(owner, title, prompt, initial);
            if (text == null) return null;
            decimal v;
            if (!decimal.TryParse(text.Trim(), out v) || v < 0)
            {
                MessageBox.Show(owner, "أدخل رقماً صحيحاً", title, MessageBoxButton.OK, MessageBoxImage.Warning);
                return null;
            }
            return v;
        }

        private void Ok_Click(object sender, RoutedEventArgs e) { DialogResult = true; Close(); }
        private void Cancel_Click(object sender, RoutedEventArgs e) { DialogResult = false; Close(); }
        private void ValueBox_KeyDown(object sender, KeyEventArgs e)
        {
            if (e.Key == Key.Enter) { DialogResult = true; Close(); }
        }
    }
}
