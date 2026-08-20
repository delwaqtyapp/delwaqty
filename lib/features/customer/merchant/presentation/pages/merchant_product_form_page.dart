import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/customer/merchant/merchant_module.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _merchantIdProvider = Provider<String>((_) => 'current-merchant-id');

final _productProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, productId) async {
  if (productId == 'new') return null;
  final repo = ref.watch(merchantDashboardRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  final products = await repo.getMerchantProducts(merchantId);
  try {
    return products.firstWhere((p) => p['id'] == productId);
  } catch (_) {
    return null;
  }
});

class MerchantProductFormPage extends ConsumerStatefulWidget {
  const MerchantProductFormPage({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<MerchantProductFormPage> createState() =>
      _MerchantProductFormPageState();
}

class _MerchantProductFormPageState
    extends ConsumerState<MerchantProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _isAvailable = true;
  bool _isFeatured = false;
  bool _isSaving = false;

  bool get _isEditing => widget.productId != null && widget.productId != 'new';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
    }
  }

  Future<void> _loadProduct() async {
    final productAsync = ref.read(_productProvider(widget.productId!));
    final product = productAsync.valueOrNull;
    if (product != null) {
      _nameController.text = product['name'] as String? ?? '';
      _descriptionController.text = product['description'] as String? ?? '';
      _priceController.text =
          (product['price'] as num?)?.toString() ?? '';
      _categoryController.text = product['category'] as String? ?? '';
      _imageUrlController.text = product['image_url'] as String? ?? '';
      setState(() {
        _isAvailable = product['is_available'] as bool? ?? true;
        _isFeatured = product['is_featured'] as bool? ?? false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _isEditing ? l10n.editProduct : l10n.addProduct;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isSaving) const AppLoaderCircular(size: 20, strokeWidth: 2),
        ],
      ),
      body: _isEditing && _nameController.text.isEmpty
          ? const Center(child: AppLoaderCircular())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedFadeIn(
                      child: _buildImagePreview(),
                    ),
                    const SizedBox(height: 16),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 100),
                      child: _buildBasicFields(l10n),
                    ),
                    const SizedBox(height: 16),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 200),
                      child: _buildToggles(l10n),
                    ),
                    const SizedBox(height: 24),
                    AnimatedFadeIn(
                      delay: const Duration(milliseconds: 300),
                      child: FilledButton(
                        onPressed: _isSaving ? null : () => _save(l10n),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isEditing ? l10n.saveChanges : l10n.create,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePreview() {
    final url = _imageUrlController.text;
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).invalidImageUrl,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 48,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).addProductImage,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBasicFields(AppLocalizations l10n) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.productName,
                hintText: l10n.enterProductName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.fieldRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.description,
                hintText: l10n.enterDescription,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: l10n.price,
                hintText: '0.00',
                prefixText: '${l10n.currencySymbol} ',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.fieldRequired;
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return l10n.invalidPrice;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: l10n.category,
                hintText: l10n.enterCategory,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: InputDecoration(
                labelText: l10n.imageUrl,
                hintText: 'https://...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link_outlined),
              ),
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggles(AppLocalizations l10n) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(l10n.available),
            subtitle: Text(l10n.productAvailableHint),
            value: _isAvailable,
            onChanged: (value) => setState(() => _isAvailable = value),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: Text(l10n.featured),
            subtitle: Text(l10n.featuredProductHint),
            value: _isFeatured,
            onChanged: (value) => setState(() => _isFeatured = value),
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(merchantDashboardRepositoryProvider);
      final merchantId = ref.read(_merchantIdProvider);

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'category': _categoryController.text.trim(),
        'image_url': _imageUrlController.text.trim(),
        'is_available': _isAvailable,
        'is_featured': _isFeatured,
      };

      if (_isEditing) {
        await repo.updateProduct(widget.productId!, productData);
      } else {
        await repo.createProduct(merchantId, productData);
      }

      if (mounted) {
        ref.invalidate(_productsProvider);
        context.pop();
        context.showAppSnackBar(
          _isEditing ? l10n.productUpdated : l10n.productCreated,
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(l10n.somethingWentWrong, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

final _productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(merchantDashboardRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  return repo.getMerchantProducts(merchantId);
});
