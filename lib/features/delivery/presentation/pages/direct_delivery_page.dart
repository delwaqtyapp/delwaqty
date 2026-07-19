import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/auth/domain/auth_state.dart';
import 'package:delwaqty/features/auth/presentation/auth_provider.dart';

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
      _items.add(_ShoppingItem(name: name, quantity: qty));
      _itemNameController.clear();
      _itemQtyController.text = '1';
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
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
                  _buildField(
                    context: context,
                    controller: _dropoffController,
                    label: l10n.deliverTo,
                    icon: Icons.location_on_outlined,
                    color: cs.error,
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(l10n.setMyLocation),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                        side: BorderSide(color: cs.primary.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(item.name, style: const TextStyle(fontSize: 14)),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text('x${item.quantity}', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
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

  const _ShoppingItem({
    required this.name,
    required this.quantity,
  });
}
