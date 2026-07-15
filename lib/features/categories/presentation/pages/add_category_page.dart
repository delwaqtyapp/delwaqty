import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/core/utils/icon_mapper.dart';
import 'package:delwaqty/features/expenses/expenses_module.dart';
import 'package:delwaqty/domain/entities/category.dart';
import 'package:delwaqty/shared/widgets/app_text_field.dart';
import 'package:delwaqty/shared/widgets/app_button.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

const _kColorOptions = [
  0xFF4CAF50,
  0xFFFF9800,
  0xFFE91E63,
  0xFF2196F3,
  0xFF9C27B0,
  0xFFFF5722,
  0xFF795548,
  0xFF607D8B,
  0xFF00BCD4,
  0xFF8BC34A,
  0xFFCDDC39,
  0xFFF44336,
];

class AddCategoryPage extends ConsumerStatefulWidget {
  const AddCategoryPage({super.key, this.existingCategory});

  final Category? existingCategory;

  @override
  ConsumerState<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends ConsumerState<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  late String _selectedIcon;
  late int _selectedColor;
  bool _isSaving = false;

  bool get _isEditing => widget.existingCategory != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _budgetController = TextEditingController(
      text: cat != null && cat.budget > 0 ? cat.budget.toStringAsFixed(0) : '',
    );
    _selectedIcon = cat?.icon ?? 'category';
    _selectedColor = cat?.colorValue ?? 0xFF4CAF50;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(categoryRepositoryProvider);
      final budget = double.tryParse(_budgetController.text) ?? 0;

      if (_isEditing) {
        await repo.updateCategory(
          id: widget.existingCategory!.id,
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          colorValue: _selectedColor,
          budget: budget,
        );
      } else {
        await repo.createCategory(
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          colorValue: _selectedColor,
          budget: budget,
        );
      }

      ref.invalidate(categoriesProvider);

      if (mounted) {
        context.pop();
        context.showAppSnackBar(
          _isEditing ? 'Category updated' : 'Category created',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editCategory : l10n.addCategory),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _nameController,
              label: l10n.categoryName,
              prefixIcon: const Icon(Icons.label_outline_rounded),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.requiredField : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.selectIcon,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: kCategoryIcons.length,
              itemBuilder: (context, index) {
                final entry = kCategoryIcons.entries.elementAt(index);
                final isSelected = _selectedIcon == entry.key;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      size: 22,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              l10n.selectColor,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _kColorOptions.map((colorVal) {
                final isSelected = _selectedColor == colorVal;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorVal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(colorVal),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Color(colorVal).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _budgetController,
              label: l10n.budget,
              hint: '0',
              prefixIcon: const Icon(Icons.attach_money_rounded),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),
            AppButton(
              onPressed: _save,
              isLoading: _isSaving,
              isExpanded: true,
              child: Text(_isEditing ? l10n.save : l10n.addCategory),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              AppButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.delete),
                            content: Text(l10n.confirmDeleteCategory),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  l10n.delete,
                                  style: TextStyle(
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await ref
                              .read(categoryRepositoryProvider)
                              .deleteCategory(widget.existingCategory!.id);
                          ref.invalidate(categoriesProvider);
                          if (context.mounted) context.pop();
                        }
                      },
                variant: AppButtonVariant.outlined,
                isExpanded: true,
                child: Text(
                  l10n.delete,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
