using System.Collections.Generic;
using System.Linq;
using System.Windows;
using Delwaqty.Pos.Core.Sync;

namespace Delwaqty.Pos.Wpf
{
    /// <summary>Pick an existing POS customer (for آجل) or create one on the spot.</summary>
    public partial class CustomerDialog : Window
    {
        private readonly List<PullApplier.PosCustomer> _customers;
        public PullApplier.PosCustomer Selected { get; private set; }
        /// <summary>Set when a brand-new (not yet synced) customer was created.</summary>
        public string NewCustomerName { get; private set; }
        public string NewCustomerPhone { get; private set; }

        public CustomerDialog(IEnumerable<PullApplier.PosCustomer> customers)
        {
            InitializeComponent();
            _customers = (customers ?? Enumerable.Empty<PullApplier.PosCustomer>()).ToList();
            Refresh("");
        }

        private void Refresh(string filter)
        {
            var f = (filter ?? "").Trim();
            CustomersGrid.ItemsSource = _customers
                .Where(c => f.Length == 0 ||
                    (c.Name != null && c.Name.Contains(f)) ||
                    (c.Phone != null && c.Phone.Contains(f)))
                .OrderByDescending(c => c.Balance)
                .ToList();
        }

        private void Filter_Changed(object sender, System.Windows.Controls.TextChangedEventArgs e)
        {
            Refresh(FilterBox.Text);
        }

        private void Pick_Click(object sender, RoutedEventArgs e)
        {
            Selected = CustomersGrid.SelectedItem as PullApplier.PosCustomer;
            if (Selected == null)
        {
                // Allow quick-pick by typed name when nothing is selected.
                var typed = (FilterBox.Text ?? "").Trim();
                if (typed.Length > 0)
                {
                    Selected = _customers.FirstOrDefault(c => c.Name == typed);
                }
            }
            if (Selected == null)
            {
                MessageBox.Show(this, "اختر عميلاً من القائمة أو احفظ عميلاً جديداً", "اختيار عميل",
                    MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }
            DialogResult = true;
            Close();
        }

        private void Create_Click(object sender, RoutedEventArgs e)
        {
            var name = (NewNameBox.Text ?? "").Trim();
            if (name.Length == 0)
            {
                MessageBox.Show(this, "اكتب اسم العميل أولاً", "عميل جديد",
                    MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }
            NewCustomerName = name;
            NewCustomerPhone = (NewPhoneBox.Text ?? "").Trim();
            DialogResult = true;
            Close();
        }

        private void Cancel_Click(object sender, RoutedEventArgs e) { DialogResult = false; Close(); }
    }
}
