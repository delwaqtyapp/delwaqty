import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/domain/entities/expense.dart';
import 'package:delwaqty/features/expenses/expenses_module.dart';
import 'package:delwaqty/shared/widgets/app_text_field.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key, this.expenseId});

  final String? expenseId;

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  ExpenseType _selectedType = ExpenseType.expense;
  bool _isSaving = false;

  bool get _isEditing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _amountController = TextEditingController();
    _noteController = TextEditingController();

    if (_isEditing) {
      _loadExpense();
    }
  }

  void _loadExpense() {
    final expenses = ref.read(expensesProvider).valueOrNull ?? [];
    final expense = expenses.where((e) => e.id == widget.expenseId).firstOrNull;
    if (expense != null) {
      _titleController.text = expense.title;
      _amountController.text = expense.amount.toString();
      _noteController.text = expense.note ?? '';
      _selectedCategoryId = expense.categoryId;
      _selectedDate = expense.date;
      _selectedType = expense.type;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editExpense : l10n.addExpense),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _titleController,
              label: l10n.title,
              hint: l10n.titleHint,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.titleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _amountController,
              label: l10n.amount,
              hint: l10n.amountHint,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Text(
                  '\$',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.amountRequired;
                }
                final amount = double.tryParse(value.trim());
                if (amount == null || amount <= 0) {
                  return l10n.amountInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: InputDecoration(
                labelText: l10n.category,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.categoryRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.date),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _noteController,
              label: l10n.note,
              hint: l10n.noteHint,
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.type,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ExpenseType>(
              segments: [
                ButtonSegment(
                  value: ExpenseType.expense,
                  label: Text(l10n.filterExpense),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ExpenseType.income,
                  label: Text(l10n.filterIncome),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                ),
                ButtonSegment(
                  value: ExpenseType.transfer,
                  label: Text(l10n.filterTransfer),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedType = selected.first;
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(expenseRepositoryProvider);

      if (_isEditing) {
        await repo.updateExpense(
          id: widget.expenseId!,
          title: _titleController.text.trim(),
          amount: double.parse(_amountController.text.trim()),
          categoryId: _selectedCategoryId!,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
      } else {
        await repo.createExpense(
          title: _titleController.text.trim(),
          amount: double.parse(_amountController.text.trim()),
          categoryId: _selectedCategoryId!,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          type: _selectedType,
        );
      }

      ref.invalidate(expensesProvider);
      ref.invalidate(totalExpensesProvider);

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
