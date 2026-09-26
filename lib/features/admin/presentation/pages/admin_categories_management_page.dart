import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/data/repositories/category_repository_impl.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home/domain/repositories/platform_category_repository.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

final _adminCategoriesProvider =
    FutureProvider.autoDispose<List<PlatformCategory>>((ref) async {
  final repo = ref.watch(platformCategoryRepositoryProvider);
  return repo.getAllCategories();
});

class AdminCategoriesManagementPage extends ConsumerStatefulWidget {
  const AdminCategoriesManagementPage({super.key});

  @override
  ConsumerState<AdminCategoriesManagementPage> createState() =>
      _AdminCategoriesManagementPageState();
}

class _AdminCategoriesManagementPageState
    extends ConsumerState<AdminCategoriesManagementPage> {
  bool _busy = false;

  PlatformCategoryRepository get _repo =>
      ref.read(platformCategoryRepositoryProvider);

  bool get _isOwner {
    final authState = ref.read(authStateProvider);
    return authState is AuthAuthenticated && authState.user.role == 'owner';
  }

  Future<void> _refresh() async {
    ref.invalidate(_adminCategoriesProvider);
  }

  Future<void> _toggleActive(PlatformCategory cat) async {
    setState(() => _busy = true);
    try {
      await _repo.updateCategory(id: cat.id, isActive: !cat.isActive);
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateSortOrder(PlatformCategory cat, int order) async {
    setState(() => _busy = true);
    try {
      await _repo.updateCategory(id: cat.id, sortOrder: order);
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadImage(PlatformCategory cat) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      await _repo.uploadCategoryImage(
        categoryId: cat.id,
        imageBytes: bytes,
        fileName: picked.name,
      );
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeImage(PlatformCategory cat) async {
    if (cat.imageUrl == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteCategoryImage(cat.imageUrl!);
      await _repo.updateCategory(id: cat.id, name: cat.name, imageUrl: '');
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCategory(PlatformCategory cat) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCategory),
        content: Text(l10n.deleteCategoryConfirm(cat.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      if (cat.imageUrl != null && cat.imageUrl!.isNotEmpty) {
        await _repo.deleteCategoryImage(cat.imageUrl!);
      }
      await _repo.deleteCategory(cat.id);
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCategory(PlatformCategory cat) async {
    final result = await showDialog<_CategoryFormData>(
      context: context,
      builder: (_) => _CategoryEditDialog(category: cat, isOwner: _isOwner),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repo.updateCategory(
        id: cat.id,
        nameAr: result.nameAr,
        nameEn: result.nameEn,
        sortOrder: result.sortOrder,
      );
      if (_isOwner && result.imageBytes != null) {
        await _repo.uploadCategoryImage(
          categoryId: cat.id,
          imageBytes: result.imageBytes!,
          fileName: result.fileName ?? 'category.png',
        );
      }
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<_CategoryFormData>(
      context: context,
      builder: (_) => _CategoryEditDialog(isOwner: _isOwner),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final created = await _repo.createCategory(
        nameAr: result.nameAr,
        nameEn: result.nameEn,
        name: result.nameEn ?? result.nameAr ?? 'Category',
        sortOrder: result.sortOrder,
      );
      if (_isOwner && result.imageBytes != null) {
        await _repo.uploadCategoryImage(
          categoryId: created.id,
          imageBytes: result.imageBytes!,
          fileName: result.fileName ?? 'category.png',
        );
      }
      await _refresh();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(_adminCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminCategories),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _addCategory,
        backgroundColor: AppColors.brandPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text('Failed to load categories: $e'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _refresh,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_rounded,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No categories yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          final sorted = List<PlatformCategory>.from(categories)
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final cat = sorted[index];
              return _buildCategoryCard(context, l10n, cat);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    AppLocalizations l10n,
    PlatformCategory cat,
  ) {
    final isActive = cat.isActive;

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      borderColor: isActive
          ? null
          : Theme.of(context).colorScheme.outlineVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildThumbnail(cat),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.nameAr ?? cat.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.nameEn ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${l10n.sequence}: ${cat.sortOrder}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: cat.isActive,
                          onChanged: _busy ? null : (_) => _toggleActive(cat),
                          activeThumbColor: AppColors.brandPurple,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isActive)
                _IconActionButton(
                  icon: Icons.remove_rounded,
                  tooltip: l10n.sequence,
                  color: Colors.grey,
                  onTap: _busy
                      ? null
                      : () => _updateSortOrder(cat, cat.sortOrder - 1),
                ),
              if (isActive) const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.add_rounded,
                tooltip: l10n.sequence,
                color: Colors.grey,
                onTap: _busy
                    ? null
                    : () => _updateSortOrder(cat, cat.sortOrder + 1),
              ),
              const SizedBox(width: 8),
              _IconActionButton(
                icon: Icons.edit_rounded,
                tooltip: l10n.editCategory,
                color: AppColors.brandViolet,
                onTap: _busy ? null : () => _editCategory(cat),
              ),
              if (_isOwner) ...[
                const SizedBox(width: 8),
                _IconActionButton(
                  icon: Icons.cloud_upload_rounded,
                  tooltip: l10n.uploadImage,
                  color: AppColors.brandCyan,
                  onTap: _busy ? null : () => _uploadImage(cat),
                ),
                if (cat.imageUrl != null && cat.imageUrl!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _IconActionButton(
                    icon: Icons.image_not_supported_rounded,
                    tooltip: l10n.removeImage,
                    color: Colors.orange,
                    onTap: _busy ? null : () => _removeImage(cat),
                  ),
                ],
              ],
              const Spacer(),
              _IconActionButton(
                icon: Icons.delete_rounded,
                tooltip: l10n.deleteCategory,
                color: Colors.red,
                onTap: _busy ? null : () => _deleteCategory(cat),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(PlatformCategory cat) {
    if (cat.imageUrl != null && cat.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          cat.imageUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.brandPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.category_rounded,
        color: AppColors.brandPurple,
        size: 28,
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _CategoryFormData {
  const _CategoryFormData({
    this.nameAr,
    this.nameEn,
    this.sortOrder = 0,
    this.imageBytes,
    this.fileName,
  });

  final String? nameAr;
  final String? nameEn;
  final int sortOrder;
  final Uint8List? imageBytes;
  final String? fileName;
}

class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({this.category, this.isOwner = true});

  final PlatformCategory? category;
  final bool isOwner;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _nameArController;
  late final TextEditingController _nameEnController;
  late int _sortOrder;
  Uint8List? _imageBytes;
  String? _fileName;
  String? _imageUrl;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameArController =
        TextEditingController(text: widget.category?.nameAr ?? '');
    _nameEnController =
        TextEditingController(text: widget.category?.nameEn ?? '');
    _sortOrder = widget.category?.sortOrder ?? 0;
    _imageUrl = widget.category?.imageUrl;
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _fileName = picked.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(_isEditing ? l10n.editCategory : l10n.addCategory),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isOwner) ...[
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                        image: _imageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_imageBytes!),
                                fit: BoxFit.cover,
                              )
                            : _imageUrl != null && _imageUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_imageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                      ),
                      child: _imageBytes == null &&
                              (_imageUrl == null || _imageUrl!.isEmpty)
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload_rounded,
                                    color: Colors.grey[400], size: 32),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.uploadImage,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          : Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.camera_alt_rounded,
                                    size: 16, color: Colors.grey[600]),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _nameArController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: l10n.nameAr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameEnController,
                decoration: InputDecoration(
                  labelText: l10n.nameEn,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('${l10n.sortOrder}: '),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sortOrder > 0
                        ? () => setState(() => _sortOrder -= 1)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text('$_sortOrder',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: () => setState(() => _sortOrder += 1),
                    icon: const Icon(Icons.add_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _CategoryFormData(
                nameAr: _nameArController.text.isEmpty
                    ? null
                    : _nameArController.text,
                nameEn: _nameEnController.text.isEmpty
                    ? null
                    : _nameEnController.text,
                sortOrder: _sortOrder,
                imageBytes: _imageBytes,
                fileName: _fileName,
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brandPurple,
          ),
          child: Text(_isEditing ? l10n.save : l10n.create),
        ),
      ],
    );
  }
}