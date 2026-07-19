import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/location/presentation/providers/location_provider.dart';

class DirectDeliveryPage extends ConsumerStatefulWidget {
  const DirectDeliveryPage({super.key});

  @override
  ConsumerState<DirectDeliveryPage> createState() => _DirectDeliveryPageState();
}

class _DirectDeliveryPageState extends ConsumerState<DirectDeliveryPage> {
  final _dropoffController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _placeDescController = TextEditingController();
  final _phoneController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemQtyController = TextEditingController(text: '1');

  final List<_ShoppingItem> _items = [];
  bool _saveNumber = true;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
  }

  void _loadPhoneNumber() {
    final authState = ref.read(authStateProvider);
    if (authState is AuthAuthenticated && authState.user.phone != null) {
      _phoneController.text = authState.user.phone!;
    }
  }

  @override
  void dispose() {
    _dropoffController.dispose();
    _descriptionController.dispose();
    _placeDescController.dispose();
    _phoneController.dispose();
    _itemNameController.dispose();
    _itemQtyController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final qty = int.tryParse(_itemQtyController.text.trim()) ?? 1;
    if (name.isEmpty) return;

    setState(() {
      _items.add(_ShoppingItem(name: name, quantity: qty, unit: _selectedUnit));
      _itemNameController.clear();
      _itemQtyController.text = '1';
      _selectedUnit = 'piece';
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  String _selectedUnit = 'piece';

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final loc = ref.read(userLocationProvider.notifier);
      await loc.refresh();
      final value = ref.read(userLocationProvider).valueOrNull;
      if (value != null && mounted) {
        final address = value.detailedAddress.isNotEmpty
            ? value.detailedAddress
            : '${value.latitude}, ${value.longitude}';
        _dropoffController.text = address;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).locationError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.directDeliveryTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.directDeliverySubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildShoppingListSection(context, l10n, cs),
                  const SizedBox(height: 12),

                  _buildField(
                    context: context,
                    controller: _descriptionController,
                    label: l10n.describeYourOrder,
                    icon: Icons.description_outlined,
                    color: cs.tertiary,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  _buildDeliverToField(context, l10n, cs),
                  const SizedBox(height: 16),

                  _buildField(
                    context: context,
                    controller: _placeDescController,
                    label: l10n.placeDescription,
                    icon: Icons.info_outline_rounded,
                    color: Colors.teal,
                    hint: l10n.placeDescriptionHint,
                  ),
                  const SizedBox(height: 16),

                  _buildPhoneSection(context, l10n, cs),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        l10n.requestDelivery,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverToField(BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _dropoffController,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.location_on_outlined, color: cs.error),
          labelText: l10n.deliverTo,
          labelStyle: TextStyle(color: cs.error),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: _loadingLocation
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  tooltip: l10n.setMyLocation,
                  color: cs.primary,
                ),
        ),
      ),
    );
  }

  Widget _buildShoppingListSection(BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.shoppingList, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 12),

          if (_items.isNotEmpty) ...[
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              final unitLabel = item.unit == 'kg' ? l10n.unitKg : l10n.unitPiece;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(item.name, style: const TextStyle(fontSize: 14)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${item.quantity} $unitLabel',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _removeItem(i),
                      icon: Icon(Icons.close_rounded, size: 18, color: cs.error),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            const SizedBox(height: 4),
          ],

          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _itemNameController,
                  decoration: InputDecoration(
                    hintText: l10n.itemName,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _itemQtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: l10n.itemQuantity,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedUnit,
                    isDense: true,
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                    items: [
                      DropdownMenuItem(value: 'piece', child: Text(l10n.unitPiece)),
                      DropdownMenuItem(value: 'kg', child: Text(l10n.unitKg)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedUnit = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded, size: 20),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneSection(BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(l10n.customerPhone, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: l10n.customerPhoneHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  if (_saveNumber) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.numberSaved), backgroundColor: Colors.green),
                    );
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Checkbox(
                value: _saveNumber,
                onChanged: (v) => setState(() => _saveNumber = v ?? true),
              ),
              Text(l10n.saveNumber, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    int maxLines = 1,
    String? hint,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: color),
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: color),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _ShoppingItem {
  final String name;
  final int quantity;
  final String unit;

  const _ShoppingItem({
    required this.name,
    required this.quantity,
    required this.unit,
  });
}
