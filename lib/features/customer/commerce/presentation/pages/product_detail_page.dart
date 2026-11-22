import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart'
    as commerce;
import 'package:delwaqty/features/customer/commerce/presentation/widgets/price_tag.dart';
import 'package:delwaqty/features/customer/commerce/presentation/widgets/cart_badge.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/product_modifier.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart'
    as restaurant;
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({
    required this.productId,
    required this.merchantId,
    this.merchantName = '',
    super.key,
  });

  final String productId;
  final String merchantId;
  final String merchantName;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _quantity = 1;
  String? _selectedVariantId;
  final _instructionsController = TextEditingController();
  final Set<String> _selectedModifierIds = {};
  List<ProductModifier> _currentModifiers = [];

  /// Required modifier groups: group id -> option ids. Every group needs at
  /// least one selected option before the item can be added to the cart.
  Map<String, Set<String>> _requiredGroups = const {};

  /// All modifier groups with their selection rules (radio / max cap).
  List<ModifierGroupInfo> _modifierGroups = const [];
  bool _modifiersLoaded = false;
  late Future<Product?> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture = _fetchProduct();
  }

  @override
  void didUpdateWidget(covariant ProductDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _quantity = 1;
      _selectedVariantId = null;
      _selectedModifierIds.clear();
      _currentModifiers = [];
      _modifiersLoaded = false;
      _productFuture = _fetchProduct();
    }
  }

  Future<Product?> _fetchProduct() =>
      ref.read(productRepositoryProvider).getProductById(widget.productId);

  void _retryLoadProduct() {
    setState(() {
      _productFuture = _fetchProduct();
    });
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadModifiers() async {
    if (_modifiersLoaded) return;
    try {
      final repo = ref.read(restaurant.modifierRepositoryProvider);
      final mods = await repo.getModifiers(widget.productId);
      final groups = await repo.getModifierGroups(widget.productId);
      if (mounted) {
        setState(() {
          _currentModifiers = mods;
          _modifierGroups = groups;
          _requiredGroups = {
            for (final g in groups)
              if (g.isRequired) g.id: g.optionIds,
          };
          _modifiersLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to load product modifiers: $e');
      if (mounted) setState(() => _modifiersLoaded = true);
    }
  }

  /// Adds an option honoring its group's selection rules, like the POS
  /// picker: single-choice groups (max 1) replace the current pick, capped
  /// groups ignore taps past the cap.
  void _addModifierSelection(String optionId) {
    ModifierGroupInfo? group;
    for (final g in _modifierGroups) {
      if (g.optionIds.contains(optionId)) {
        group = g;
        break;
      }
    }
    if (group == null) {
      _selectedModifierIds.add(optionId);
      return;
    }
    if (group.maxSelections == 1) {
      _selectedModifierIds.removeAll(group.optionIds);
      _selectedModifierIds.add(optionId);
    } else if (group.maxSelections <= 0 ||
        _selectedModifierIds.where(group.optionIds.contains).length <
            group.maxSelections) {
      _selectedModifierIds.add(optionId);
    }
  }

  /// True when a required modifier group has no selected option.
  bool get _missingRequiredModifier {
    for (final optionIds in _requiredGroups.values) {
      if (!_selectedModifierIds.any(optionIds.contains)) return true;
    }
    return false;
  }

  Widget _buildHeroPlaceholder(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: context.colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 64,
          color: context.colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<Product?>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.loading)),
            body: const SkeletonCard(),
          );
        }
        if (snapshot.hasError) {
          // Previously a failure fell through to the "product not found"
          // branch, which looks like an empty product rather than an error.
          return Scaffold(
            appBar: AppBar(title: Text(l10n.loading)),
            body: ErrorState(
              message: l10n.somethingWentWrong,
              onRetry: _retryLoadProduct,
            ),
          );
        }

        final product = snapshot.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.error)),
            body: ErrorState(message: l10n.noData, onRetry: _retryLoadProduct),
          );
        }

        if (!_modifiersLoaded) _loadModifiers();

        final selectedVariant = _selectedVariantId != null
            ? product.variants
                  .where((v) => v.id == _selectedVariantId)
                  .firstOrNull
            : null;
        final unitPrice = selectedVariant?.price ?? product.price;
        final modifierTotal = _selectedModifierIds.fold<double>(0, (sum, id) {
          final mod = _currentModifiers.where((m) => m.id == id).firstOrNull;
          return sum + (mod?.priceAdjustment ?? 0);
        });
        final totalPrice = (unitPrice + modifierTotal) * _quantity;

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [CartBadge(onTap: () => context.push('/market/cart'))],
          ),
          body: ListView(
            children: [
              Hero(
                tag: 'product-${product.id}',
                child: Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        context.colorScheme.primaryContainer.withValues(
                          alpha: 0.6,
                        ),
                        context.colorScheme.surface,
                      ],
                    ),
                  ),
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 280,
                          errorBuilder: (_, _, _) =>
                              _buildHeroPlaceholder(context),
                        )
                      : _buildHeroPlaceholder(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        product.name,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 200),
                        child: Text(
                          product.description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 300),
                      child: PriceTag(
                        price: unitPrice,
                        originalPrice: product.originalPrice,
                        size: 'large',
                      ),
                    ),
                    if (product.variants.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 400),
                        child: Text(
                          l10n.details,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 450),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: product.variants.map((v) {
                            final isSelected = v.id == _selectedVariantId;
                            return ChoiceChip(
                              label: Text(
                                '${v.name} - ${v.price.toStringAsFixed(0)} ${l10n.currencySymbol}',
                              ),
                              selected: isSelected,
                              selectedColor:
                                  context.colorScheme.primaryContainer,
                              onSelected: v.isAvailable
                                  ? (_) => setState(
                                      () => _selectedVariantId = v.id,
                                    )
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    if (_currentModifiers.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 470),
                        child: Row(
                          children: [
                            Text(
                              l10n.addOns,
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_requiredGroups.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                l10n.posModifierRequired,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: context.colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_currentModifiers.length, (i) {
                        final mod = _currentModifiers[i];
                        final isSelected = _selectedModifierIds.contains(
                          mod.id,
                        );
                        return AnimatedFadeIn(
                          delay: Duration(milliseconds: 500 + i * 40),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: mod.isAvailable
                                ? (val) => setState(() {
                                    if (val == true) {
                                      _addModifierSelection(mod.id);
                                    } else {
                                      _selectedModifierIds.remove(mod.id);
                                    }
                                  })
                                : null,
                            title: Text(
                              mod.name,
                              style: TextStyle(
                                decoration: mod.isAvailable
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                            subtitle: mod.description != null
                                ? Text(mod.description!)
                                : null,
                            secondary: Text(
                              mod.priceAdjustment >= 0
                                  ? '+${mod.priceAdjustment.toStringAsFixed(0)} ${l10n.currencySymbol}'
                                  : '-${mod.priceAdjustment.abs().toStringAsFixed(0)} ${l10n.currencySymbol}',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: mod.priceAdjustment >= 0
                                    ? context.colorScheme.primary
                                    : context.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 24),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 700),
                      child: Text(
                        l10n.quantity,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 550),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.decrease,
                              onPressed: product.isAvailable && _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: product.isAvailable && _quantity > 1
                                    ? context.colorScheme.primary
                                    : context.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                '$_quantity',
                                key: ValueKey(_quantity),
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.add,
                              onPressed: product.isAvailable
                                  ? () => setState(() => _quantity++)
                                  : null,
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: product.isAvailable
                                    ? context.colorScheme.primary
                                    : context.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 600),
                      child: TextField(
                        controller: _instructionsController,
                        decoration: InputDecoration(
                          hintText: l10n.specialInstructions,
                          hintStyle: TextStyle(
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: product.isAvailable
                    ? () async {
                        if (_missingRequiredModifier) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.productModifierRequiredError),
                            ),
                          );
                          return;
                        }
                        final selectedModifierNames = _currentModifiers
                            .where((m) => _selectedModifierIds.contains(m.id))
                            .map((m) => m.name)
                            .toList();
                        final notes = _instructionsController.text.trim();
                        final instructionsParts = [
                          if (selectedModifierNames.isNotEmpty)
                            selectedModifierNames.join(', '),
                          if (notes.isNotEmpty) notes,
                        ];
                        final specialInstructions = instructionsParts.isEmpty
                            ? null
                            : instructionsParts.join(' | ');
                        final cartNotifier = ref.read(cartProvider.notifier);
                        try {
                          await cartNotifier.addToCart(
                            merchantId: widget.merchantId,
                            merchantName: widget.merchantName,
                            item: commerce.CartItem(
                              id: 'ci_${DateTime.now().millisecondsSinceEpoch}',
                              productId: product.id,
                              productName: product.name,
                              variantName: selectedVariant?.name,
                              quantity: _quantity,
                              unitPrice: unitPrice + modifierTotal,
                              totalPrice: totalPrice,
                              specialInstructions: specialInstructions,
                              // Server re-prices these (migration 226);
                              // the client prices are display-only.
                              modifierOptionIds: _selectedModifierIds.toList(),
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${l10n.addedToCart} - ${totalPrice.toStringAsFixed(0)} ${l10n.currencySymbol}',
                                ),
                                action: SnackBarAction(
                                  label: l10n.viewCart,
                                  onPressed: () {
                                    // Dismiss first: this bar must never
                                    // overlay the cart page's checkout button.
                                    ScaffoldMessenger.of(context)
                                        .hideCurrentSnackBar();
                                    context.push('/market/cart');
                                  },
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(appErrorText(context, e))),
                            );
                          }
                        }
                      }
                    : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  '${l10n.addToCart} - ${totalPrice.toStringAsFixed(0)} ${l10n.currencySymbol}',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
