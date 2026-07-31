import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
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
  final _qtyFocusNode = FocusNode();

  final List<_ShoppingItem> _items = [];
  bool _saveNumber = true;
  bool _loadingLocation = false;

  String _selectedUnit = 'none';
  String _selectedWeight = 'none';
  String _selectedPieceUnit = 'none';

  @override
  void initState() {
    super.initState();
    _loadPhoneNumber();
    _qtyFocusNode.addListener(() {
      if (_qtyFocusNode.hasFocus) {
        _itemQtyController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _itemQtyController.text.length,
        );
      }
    });
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
    _qtyFocusNode.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final qty = int.tryParse(_itemQtyController.text.trim()) ?? 1;
    if (name.isEmpty) return;

    String? subUnit;
    if (_selectedUnit == 'kg') {
      subUnit = _selectedWeight;
    } else if (_selectedUnit == 'piece') {
      subUnit = _selectedPieceUnit;
    }

    setState(() {
      _items.add(_ShoppingItem(
        name: name,
        quantity: qty,
        unit: _selectedUnit,
        subUnit: subUnit,
      ));
      _itemNameController.clear();
      _itemQtyController.text = '1';
      _selectedUnit = 'none';
      _selectedWeight = 'none';
      _selectedPieceUnit = 'none';
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

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

  String _itemDisplayText(_ShoppingItem item, AppLocalizations l10n) {
    if (item.unit == 'kg' && item.subUnit != null && item.subUnit != 'none') {
      final label = switch (item.subUnit) {
        'eighth' => l10n.weightEighth,
        'quarter' => l10n.weightQuarter,
        'third' => l10n.weightThird,
        'half' => l10n.weightHalf,
        'three_quarters' => l10n.weightThreeQuarters,
        'fifth' => l10n.weightFifth,
        'bundle' => l10n.weightBundle,
        _ => l10n.unitKg,
      };
      return '${item.quantity} $label';
    }
    if (item.unit == 'piece' && item.subUnit != null && item.subUnit != 'none') {
      final label = switch (item.subUnit) {
        'box' => l10n.pieceUnitBox,
        'carton' => l10n.pieceUnitCarton,
        'liter' => l10n.pieceUnitLiter,
        _ => l10n.unitPiece,
      };
      return '${item.quantity} $label';
    }
    if (item.unit == 'kg') return '${item.quantity} ${l10n.unitKg}';
    if (item.unit == 'piece') return '${item.quantity} ${l10n.unitPiece}';
    return '${item.quantity}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.directDelivery)),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                    color: AppColors.orderReady,
                    hint: l10n.placeDescriptionHint,
                  ),
                  const SizedBox(height: 16),

                  _buildPhoneSection(context, l10n, cs),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        if (_dropoffController.text.trim().isEmpty) {
                          context.showAppSnackBar(l10n.deliverTo, isError: true);
                          return;
                        }
                        if (_phoneController.text.trim().isEmpty) {
                          context.showAppSnackBar(l10n.customerPhone, isError: true);
                          return;
                        }
                        context.showAppSnackBar(l10n.success);
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        l10n.requestDelivery,
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
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
          labelStyle: AppTextStyles.bodyMedium.copyWith(color: cs.error),
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
    final showSubUnits = _selectedUnit == 'kg' || _selectedUnit == 'piece';
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
              Text(l10n.shoppingList, style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface)),
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
                      child: Text(item.name, style: AppTextStyles.bodyMedium),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _itemDisplayText(item, l10n),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(fontSize: 13, color: cs.onSurfaceVariant),
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
                flex: 3,
                child: TextField(
                  controller: _itemNameController,
                  decoration: InputDecoration(
                    hintText: l10n.itemName,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 48,
                child: TextField(
                  controller: _itemQtyController,
                  focusNode: _qtyFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    hintText: '1',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              _buildUnitSelector(l10n, cs),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: _addItem,
                icon: const Icon(Icons.add_rounded, size: 20),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),

          if (showSubUnits) ...[
            const SizedBox(height: 8),
            _buildSubUnitSelector(l10n, cs),
          ],
        ],
      ),
    );
  }

  Widget _buildUnitSelector(AppLocalizations l10n, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedUnit,
          isDense: true,
          style: AppTextStyles.labelSmall.copyWith(color: cs.onSurface),
          items: [
            DropdownMenuItem(value: 'none', child: Text(l10n.unitNone)),
            DropdownMenuItem(value: 'piece', child: Text(l10n.unitPiece)),
            DropdownMenuItem(value: 'kg', child: Text(l10n.unitKg)),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _selectedUnit = v;
                _selectedWeight = 'none';
                _selectedPieceUnit = 'none';
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSubUnitSelector(AppLocalizations l10n, ColorScheme cs) {
    if (_selectedUnit == 'kg') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.scale_outlined, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedWeight,
                  isDense: true,
                  isExpanded: true,
                  style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
                  items: [
                    DropdownMenuItem(value: 'none', child: Text(l10n.weightNone)),
                    DropdownMenuItem(value: 'bundle', child: Text(l10n.weightBundle)),
                    DropdownMenuItem(value: 'eighth', child: Text(l10n.weightEighth)),
                    DropdownMenuItem(value: 'quarter', child: Text(l10n.weightQuarter)),
                    DropdownMenuItem(value: 'third', child: Text(l10n.weightThird)),
                    DropdownMenuItem(value: 'half', child: Text(l10n.weightHalf)),
                    DropdownMenuItem(value: 'three_quarters', child: Text(l10n.weightThreeQuarters)),
                    DropdownMenuItem(value: 'fifth', child: Text(l10n.weightFifth)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedWeight = v);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPieceUnit,
                isDense: true,
                isExpanded: true,
                style: AppTextStyles.bodySmall.copyWith(color: cs.onSurface),
                items: [
                  DropdownMenuItem(value: 'none', child: Text(l10n.unitNone)),
                  DropdownMenuItem(value: 'box', child: Text(l10n.pieceUnitBox)),
                  DropdownMenuItem(value: 'carton', child: Text(l10n.pieceUnitCarton)),
                  DropdownMenuItem(value: 'liter', child: Text(l10n.pieceUnitLiter)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPieceUnit = v);
                },
              ),
            ),
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
              Text(l10n.customerPhone, style: AppTextStyles.titleMedium.copyWith(color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                  ],
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
                      SnackBar(content: Text(l10n.numberSaved), backgroundColor: AppColors.successLight),
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
              Text(l10n.saveNumber, style: AppTextStyles.bodyMedium.copyWith(fontSize: 13, color: cs.onSurfaceVariant)),
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
          labelStyle: AppTextStyles.bodyMedium.copyWith(color: color),
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
  final String? subUnit;

  const _ShoppingItem({
    required this.name,
    required this.quantity,
    required this.unit,
    this.subUnit,
  });
}
