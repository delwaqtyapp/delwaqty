import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';

class ProductDetailBottomSheet extends ConsumerStatefulWidget {
  const ProductDetailBottomSheet({
    required this.product,
    required this.merchantId,
    required this.merchantName,
    required this.merchantType,
    super.key,
  });

  final Product product;
  final String merchantId;
  final String merchantName;
  final MerchantType merchantType;

  @override
  ConsumerState<ProductDetailBottomSheet> createState() =>
      _ProductDetailBottomSheetState();
}

class _ProductDetailBottomSheetState
    extends ConsumerState<ProductDetailBottomSheet> {
  int _quantity = 1;
  String? _selectedVariantId;
  final _instructionsController = TextEditingController();

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  ProductVariant? get _selectedVariant => widget.product.variants.isEmpty
      ? null
      : widget.product.variants.firstWhere(
          (v) => v.id == _selectedVariantId,
          orElse: () => widget.product.variants.first,
        );

  double get _unitPrice => _selectedVariant?.price ?? widget.product.price;

  double get _totalPrice => _unitPrice * _quantity;

  Map<String, String> get _parsedTags {
    final result = <String, String>{};
    for (final tag in widget.product.tags) {
      final parts = tag.split(':');
      if (parts.length == 2) {
        result[parts[0].trim()] = parts[1].trim();
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final product = widget.product;
    final tags = _parsedTags;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusSheet),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImage(product),
                    const SizedBox(height: 16),
                    _buildHeader(product, l10n),
                    if (product.variants.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildVariants(l10n),
                    ],
                    const SizedBox(height: 16),
                    _buildQuantitySelector(l10n),
                    const SizedBox(height: 16),
                    _buildSpecialInstructions(l10n),
                    const SizedBox(height: 16),
                    _buildAdaptiveInfo(tags, l10n),
                    const SizedBox(height: 16),
                    _buildAddToCartButton(l10n),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImage(Product product) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colorScheme.primaryContainer.withValues(alpha: 0.3),
              context.colorScheme.surface,
            ],
          ),
        ),
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
              ? Image.network(
                  product.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImageFallback(product),
                )
              : _buildImageFallback(product),
        ),
      ),
    );
  }

  Widget _buildImageFallback(Product product) {
    return Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 48,
        color: context.colorScheme.primary.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildHeader(Product product, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                product.name,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (product.originalPrice != null &&
                product.originalPrice! > product.price)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colorScheme.error,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  l10n.discountPercent(
                    ((1 - product.price / product.originalPrice!) * 100)
                        .round(),
                  ),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        if (product.description != null && product.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            product.description!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '${_unitPrice.toStringAsFixed(0)} ${l10n.currencySymbol}',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.colorScheme.primary,
              ),
            ),
            if (product.originalPrice != null &&
                product.originalPrice! > product.price) ...[
              const SizedBox(width: 8),
              Text(
                '${product.originalPrice!.toStringAsFixed(0)} ${l10n.currencySymbol}',
                style: context.textTheme.bodyMedium?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        if (!product.isAvailable) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: context.colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text(
              l10n.unavailable,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVariants(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.options,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.product.variants.map((variant) {
            final isSelected = _selectedVariantId == variant.id ||
                (variant.id == widget.product.variants.first.id &&
                    _selectedVariantId == null);
            return GestureDetector(
              onTap: variant.isAvailable
                  ? () => setState(() => _selectedVariantId = variant.id)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [AppColors.brandGradientStart, AppColors.brandGradientEnd],
                        )
                      : null,
                  color: isSelected ? null : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      variant.name,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: isSelected ? Colors.white : context.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${variant.price.toStringAsFixed(0)} ${l10n.currencySymbol}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector(AppLocalizations l10n) {
    return Row(
      children: [
        Text(
          l10n.quantity,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '$_quantity',
                  key: ValueKey(_quantity),
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => setState(() => _quantity++),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialInstructions(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.specialInstructions,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _instructionsController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: l10n.specialInstructionsHint,
            filled: true,
            fillColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildAdaptiveInfo(Map<String, String> tags, AppLocalizations l10n) {
    final infoItems = <_InfoItem>[];

    switch (widget.merchantType) {
      case MerchantType.restaurant:
        if (tags.containsKey('calories')) {
          infoItems.add(_InfoItem(Icons.local_fire_department_outlined, l10n.calories, tags['calories']!));
        }
        if (tags.containsKey('ingredients')) {
          infoItems.add(_InfoItem(Icons.eco_outlined, l10n.ingredients, tags['ingredients']!));
        }
        if (tags.containsKey('prep_time')) {
          infoItems.add(_InfoItem(Icons.timer_outlined, l10n.preparationTime, tags['prep_time']!));
        }
      case MerchantType.pharmacy:
        if (tags.containsKey('dosage')) {
          infoItems.add(_InfoItem(Icons.medication_outlined, l10n.dosageForm, tags['dosage']!));
        }
        if (tags.containsKey('active_ingredient')) {
          infoItems.add(_InfoItem(Icons.science_outlined, l10n.activeIngredient, tags['active_ingredient']!));
        }
        if (tags['prescription'] == 'true') {
          infoItems.add(_InfoItem(Icons.receipt_outlined, l10n.prescriptionRequired, ''));
        }
        if (tags.containsKey('warnings')) {
          infoItems.add(_InfoItem(Icons.warning_amber_outlined, l10n.warnings, tags['warnings']!));
        }
      case MerchantType.grocery:
        if (tags.containsKey('weight')) {
          infoItems.add(_InfoItem(Icons.scale_outlined, l10n.weight, tags['weight']!));
        }
        if (tags.containsKey('expiry')) {
          infoItems.add(_InfoItem(Icons.calendar_today_outlined, l10n.expiryDate, tags['expiry']!));
        }
        if (tags.containsKey('storage')) {
          infoItems.add(_InfoItem(Icons.kitchen_outlined, l10n.storageInstructions, tags['storage']!));
        }
      case MerchantType.bakery:
        if (tags.containsKey('ingredients')) {
          infoItems.add(_InfoItem(Icons.eco_outlined, l10n.ingredients, tags['ingredients']!));
        }
        if (tags.containsKey('allergens')) {
          infoItems.add(_InfoItem(Icons.warning_amber_outlined, l10n.allergens, tags['allergens']!));
        }
      case MerchantType.home:
        if (tags.containsKey('duration')) {
          infoItems.add(_InfoItem(Icons.schedule_outlined, l10n.serviceDuration, tags['duration']!));
        }
        if (tags.containsKey('included')) {
          infoItems.add(_InfoItem(Icons.check_circle_outline, l10n.whatsIncluded, tags['included']!));
        }
      default:
        break;
    }

    if (infoItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.details,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...infoItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 18, color: context.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: context.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.value.isNotEmpty)
                      Text(
                        item.value,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildAddToCartButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: widget.product.isAvailable
            ? () async {
                final cartRepo = ref.read(cartRepositoryProvider);
                final item = CartItem(
                  id: '',
                  productId: widget.product.id,
                  productName: widget.product.name,
                  variantName: _selectedVariant?.name,
                  quantity: _quantity,
                  unitPrice: _unitPrice,
                  totalPrice: _totalPrice,
                  specialInstructions: _instructionsController.text.isEmpty
                      ? null
                      : _instructionsController.text,
                );
                await cartRepo.addToCart(
                  merchantId: widget.merchantId,
                  merchantName: widget.merchantName,
                  item: item,
                );
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.addedToCart),
                      action: SnackBarAction(
                        label: l10n.viewCart,
                        onPressed: () {
                          context.push('/market/cart');
                        },
                      ),
                    ),
                  );
                }
              }
            : null,
        icon: const Icon(Icons.shopping_cart_outlined, size: 20),
        label: Text(
          '${l10n.addToCart} - ${_totalPrice.toStringAsFixed(0)} ${l10n.currencySymbol}',
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _InfoItem {
  const _InfoItem(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}
