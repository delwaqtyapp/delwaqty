import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/features/provider/merchant/presentation/providers/merchant_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/provider/merchant/merchant_module.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _merchantIdProvider = providerMerchantIdProvider;

final _productProvider = FutureProvider.family<Map<String, dynamic>?, String>((
  ref,
  productId,
) async {
  if (productId == 'new') return null;
  final repo = ref.watch(merchantDashboardRepositoryProvider);
  final merchantId = await ref.watch(_merchantIdProvider.future);
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
  bool _isUploadingPhoto = false;
  bool _isLoadingInitial = false;

  bool get _isEditing => widget.productId != null && widget.productId != 'new';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _isLoadingInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
    }
  }

  Future<void> _loadProduct() async {
    try {
      final product = await ref.read(
        _productProvider(widget.productId!).future,
      );
      if (!mounted || product == null) return;
      _nameController.text = product['name'] as String? ?? '';
      _descriptionController.text = product['description'] as String? ?? '';
      _priceController.text = (product['price'] as num?)?.toString() ?? '';
      _categoryController.text = product['category'] as String? ?? '';
      _imageUrlController.text = product['image_url'] as String? ?? '';
      setState(() {
        _isAvailable = product['is_available'] as bool? ?? true;
        _isFeatured = product['is_featured'] as bool? ?? false;
      });
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(appErrorText(context, e), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitial = false);
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;
    final l10n = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _isUploadingPhoto = true);
      final bytes = await picked.readAsBytes();
      final name = picked.name.isEmpty ? 'photo.jpg' : picked.name;
      final client = ref.read(supabaseClientProvider);
      final uid = client.auth.currentUser?.id ?? 'anon';
      final path =
          '$uid/products/${DateTime.now().millisecondsSinceEpoch}_$name';
      await client.storage.from('profile-photos').uploadBinary(path, bytes);
      final publicUrl = client.storage
          .from('profile-photos')
          .getPublicUrl(path);
      if (mounted) {
        setState(() {
          _imageUrlController.text = publicUrl;
        });
      }
    } catch (_) {
      if (mounted) {
        context.showAppSnackBar(l10n.somethingWentWrong, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
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
          if (_isEditing)
            IconButton(
              tooltip: l10n.modifiersManage,
              icon: const Icon(Icons.tune),
              onPressed: () => context.push(
                '/merchant-dashboard/products/${widget.productId}/modifiers',
              ),
            ),
          if (_isSaving) const AppLoaderCircular(size: 20, strokeWidth: 2),
        ],
      ),
      body: _isLoadingInitial
          ? const Center(child: AppLoaderCircular())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedFadeIn(child: _buildImagePreview(l10n)),
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
                    // Keep the primary action clear of the shell's floating
                    // bottom navigation bar.
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePreview(AppLocalizations l10n) {
    final url = _imageUrlController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                  errorBuilder: (_, _, _) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.invalidImageUrl,
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
                      l10n.addProductImage,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
          icon: _isUploadingPhoto
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_rounded),
          label: Text(l10n.uploadProductPhoto),
        ),
      ],
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  tooltip: l10n.category,
                  onPressed: _openCategoryPicker,
                ),
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCategoryPicker() async {
    final repo = ref.read(merchantDashboardRepositoryProvider);
    final merchantId = await ref.read(_merchantIdProvider.future);
    if (!mounted) return;
    List<String> categories;
    try {
      final products = await repo.getMerchantProducts(merchantId);
      categories =
          products
              .map((p) => (p['category'] as String? ?? '').trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
    } catch (_) {
      categories = const [];
    }
    if (!mounted || categories.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in categories)
              ListTile(
                title: Text(c),
                onTap: () => Navigator.of(sheetCtx).pop(c),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _categoryController.text = picked);
    }
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(merchantDashboardRepositoryProvider);
      // Read through the future so a still-resolving id can never
      // silently become an empty string and write the product with a null
      // merchant.
      final merchantId = await ref.read(providerMerchantIdProvider.future);

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
        ref.invalidate(merchantProductsProvider);
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
