import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/data/repositories/category_repository_impl.dart';
import 'package:delwaqty/features/customer/home/domain/entities/platform_category.dart';
import 'package:delwaqty/features/customer/home/domain/repositories/platform_category_repository.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final _allCategoriesProvider =
    FutureProvider.autoDispose<List<PlatformCategory>>((ref) async {
  final repo = ref.watch(platformCategoryRepositoryProvider);
  return repo.getAllCategories();
});

class AdminCategoriesPage extends ConsumerStatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  ConsumerState<AdminCategoriesPage> createState() =>
      _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends ConsumerState<AdminCategoriesPage> {
  bool _saving = false;

  Future<void> _refresh() async {
    ref.invalidate(_allCategoriesProvider);
  }

  PlatformCategoryRepository get _repo =>
      ref.read(platformCategoryRepositoryProvider);

  Future<void> _toggleActive(PlatformCategory cat) async {
    setState(() => _saving = true);
    try {
      await _repo.updateCategory(id: cat.id, isActive: !cat.isActive);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateSortOrder(PlatformCategory cat, int order) async {
    setState(() => _saving = true);
    try {
      await _repo.updateCategory(id: cat.id, sortOrder: order);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    if (picked == null) return;

    setState(() => _saving = true);
    try {
      final bytes = await picked.readAsBytes();
      await _repo.uploadCategoryImage(
        categoryId: cat.id,
        imageBytes: bytes,
        fileName: picked.name,
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteImage(PlatformCategory cat) async {
    if (cat.imageUrl == null) return;
    setState(() => _saving = true);
    try {
      await _repo.deleteCategoryImage(cat.imageUrl!);
      await Supabase.instance.client
          .from('categories')
          .update({'image_url': null}).eq('id', cat.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      if (cat.imageUrl != null) {
        await _repo.deleteCategoryImage(cat.imageUrl!);
      }
      await _repo.deleteCategory(cat.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editCategory(PlatformCategory cat) async {
    final result = await showDialog<_CategoryFormData>(
      context: context,
      builder: (_) => _CategoryDialog(category: cat),
    );
    if (result == null) return;

    setState(() => _saving = true);
    try {
      await _repo.updateCategory(
        id: cat.id,
        nameAr: result.nameAr,
        nameEn: result.nameEn,
        sortOrder: result.sortOrder,
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<_CategoryFormData>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );
    if (result == null) return;

    setState(() => _saving = true);
    try {
      final created = await _repo.createCategory(
        nameAr: result.nameAr,
        nameEn: result.nameEn,
        name: result.nameEn ?? result.nameAr ?? 'Category',
        sortOrder: result.sortOrder,
      );

      if (result.imageBytes != null) {
        await _repo.uploadCategoryImage(
          categoryId: created.id,
          imageBytes: result.imageBytes!,
          fileName: result.fileName ?? 'category.png',
        );
      }

      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(_allCategoriesProvider);
    final authState = ref.watch(authStateProvider);
    final isOwner =
        authState is AuthAuthenticated && authState.user.role == 'owner';

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Categories',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1035),
                  ),
                ),
              ),
              if (_saving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _addCategory,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(l10n.addCategory),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Manage store categories, images, and display order',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: categoriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
                        const SizedBox(height: 8),
                        Text(
                          'Add your first category to get started',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  );
                }

                final sorted = List<PlatformCategory>.from(categories)
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

                return PremiumCard(
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.brandPurple.withValues(alpha: 0.06),
                      ),
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1A1035),
                      ),
                      columns: [
                        DataColumn(label: Text(l10n.image)),
                        DataColumn(label: Text(l10n.nameAr)),
                        DataColumn(label: Text(l10n.nameEn)),
                        DataColumn(label: Text(l10n.sequence)),
                        DataColumn(label: Text(l10n.active)),
                        DataColumn(label: Text(l10n.actions)),
                      ],
                      rows: sorted.map((cat) {
                        return DataRow(cells: [
                          DataCell(_buildThumbnail(cat)),
                          DataCell(
                            _EditableTextField(
                              value: cat.nameAr ?? '',
                              onSubmitted: (v) async {
                                setState(() => _saving = true);
                                try {
                                  await _repo.updateCategory(
                                      id: cat.id, nameAr: v);
                                  await _refresh();
                                } catch (_) {}
                                if (mounted) {
                                  setState(() => _saving = false);
                                }
                              },
                            ),
                          ),
                          DataCell(
                            _EditableTextField(
                              value: cat.nameEn ?? '',
                              onSubmitted: (v) async {
                                setState(() => _saving = true);
                                try {
                                  await _repo.updateCategory(
                                      id: cat.id, nameEn: v);
                                  await _refresh();
                                } catch (_) {}
                                if (mounted) {
                                  setState(() => _saving = false);
                                }
                              },
                            ),
                          ),
                          DataCell(
                            _SortOrderSpinner(
                              value: cat.sortOrder,
                              onChanged: (v) => _updateSortOrder(cat, v),
                            ),
                          ),
                          DataCell(
                            Switch(
                              value: cat.isActive,
                              onChanged: (_) => _toggleActive(cat),
                              activeThumbColor: AppColors.brandPurple,
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionIconButton(
                                  icon: Icons.edit_rounded,
                                  tooltip: 'Edit',
                                  color: AppColors.brandViolet,
                                  onTap: () => _editCategory(cat),
                                ),
                                const SizedBox(width: 4),
                                if (isOwner) ...[
                                  _ActionIconButton(
                                    icon: Icons.cloud_upload_rounded,
                                    tooltip: 'Upload image',
                                    color: AppColors.brandCyan,
                                    onTap: () => _uploadImage(cat),
                                  ),
                                  if (cat.imageUrl != null) ...[
                                    const SizedBox(width: 4),
                                    _ActionIconButton(
                                      icon: Icons.image_not_supported_rounded,
                                      tooltip: 'Remove image',
                                      color: Colors.orange,
                                      onTap: () => _deleteImage(cat),
                                    ),
                                  ],
                                ],
                                const SizedBox(width: 4),
                                _ActionIconButton(
                                  icon: Icons.delete_rounded,
                                  tooltip: 'Delete',
                                  color: Colors.red,
                                  onTap: () => _deleteCategory(cat),
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(PlatformCategory cat) {
    if (cat.imageUrl != null && cat.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          cat.imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(cat),
        ),
      );
    }
    return _fallbackIcon(cat);
  }

  Widget _fallbackIcon(PlatformCategory cat) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.brandPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.category_rounded,
        color: AppColors.brandPurple,
        size: 24,
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _EditableTextField extends StatefulWidget {
  const _EditableTextField({
    required this.value,
    required this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onSubmitted;

  @override
  State<_EditableTextField> createState() => _EditableTextFieldState();
}

class _EditableTextFieldState extends State<_EditableTextField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_EditableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: 180,
        child: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: (v) {
            setState(() => _editing = false);
            widget.onSubmitted(v);
          },
          onTapOutside: (_) {
            setState(() => _editing = false);
            widget.onSubmitted(_controller.text);
          },
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _editing = true),
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.transparent),
        ),
        child: Text(
          widget.value.isEmpty ? '-' : widget.value,
          style: TextStyle(
            fontSize: 13,
            color: widget.value.isEmpty ? Colors.grey[400] : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SortOrderSpinner extends StatelessWidget {
  const _SortOrderSpinner({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: value > 0 ? () => onChanged(value - 1) : null,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(7)),
            child: Container(
              width: 28,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.remove_rounded,
                size: 16,
                color: value > 0 ? Colors.grey[600] : Colors.grey[300],
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          InkWell(
            onTap: () => onChanged(value + 1),
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(7)),
            child: Container(
              width: 28,
              height: 32,
              alignment: Alignment.center,
              child: Icon(
                Icons.add_rounded,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
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

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({this.category});

  final PlatformCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
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
    if (picked == null) return;
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
      title: Text(_isEditing ? 'Edit Category' : l10n.addCategory),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey[300]!,
                      ),
                      image: _imageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_imageBytes!),
                              fit: BoxFit.cover,
                            )
                          : _imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: _imageBytes == null && _imageUrl == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_rounded,
                                  color: Colors.grey[400], size: 32),
                              const SizedBox(height: 4),
                              Text(
                                'Upload',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
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
              const SizedBox(height: 20),
              TextField(
                controller: _nameArController,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'الاسم بالعربي',
                  hintText: 'اسم التصنيف',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameEnController,
                decoration: InputDecoration(
                  labelText: 'Name (English)',
                  hintText: 'Category name',
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
                  _SortOrderSpinner(
                    value: _sortOrder,
                    onChanged: (v) => setState(() => _sortOrder = v),
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
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
