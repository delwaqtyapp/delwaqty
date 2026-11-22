import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Merchant modifier-group management for one product: groups (name,
/// required, max selections) and their options (name, price adjustment).
/// This is the data the POS picker and the customer product page read
/// (product_modifier_groups / product_modifier_options).
class MerchantProductModifiersPage extends ConsumerStatefulWidget {
  const MerchantProductModifiersPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<MerchantProductModifiersPage> createState() =>
      _MerchantProductModifiersPageState();
}

class _MerchantProductModifiersPageState
    extends ConsumerState<MerchantProductModifiersPage> {
  List<Map<String, dynamic>> _groups = [];
  Map<String, List<Map<String, dynamic>>> _options = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final groups = await client
          .from('product_modifier_groups')
          .select('id, name, name_ar, is_required, max_selections, sort_order')
          .eq('product_id', widget.productId)
          .order('sort_order');
      final groupRows = (groups as List).cast<Map<String, dynamic>>();
      final options = <String, List<Map<String, dynamic>>>{};
      if (groupRows.isNotEmpty) {
        final rows = await client
            .from('product_modifier_options')
            .select('id, group_id, name, name_ar, price_adjustment, sort_order')
            .inFilter('group_id', [
              for (final g in groupRows) g['id'] as String,
            ])
            .order('sort_order');
        for (final o in (rows as List).cast<Map<String, dynamic>>()) {
          options.putIfAbsent(o['group_id'] as String, () => []).add(o);
        }
      }
      if (!mounted) return;
      setState(() {
        _groups = groupRows;
        _options = options;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editGroup([Map<String, dynamic>? group]) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: group?['name']?.toString());
    final nameArCtrl = TextEditingController(
      text: group?['name_ar']?.toString(),
    );
    final maxCtrl = TextEditingController(
      text: '${(group?['max_selections'] as num?)?.toInt() ?? 1}',
    );
    var required = group?['is_required'] == true;
    var saving = false;
    String? errorText;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.modifierGroupTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.modifierNameEn),
              ),
              TextField(
                controller: nameArCtrl,
                decoration: InputDecoration(labelText: l10n.modifierNameAr),
              ),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.modifierMaxSelections,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.posModifierRequired),
                value: required,
                onChanged: saving
                    ? null
                    : (v) => setDialogState(() => required = v),
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: AppColors.errorLight),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final nameAr = nameArCtrl.text.trim();
                      final maxSel = int.tryParse(maxCtrl.text.trim());
                      if (name.isEmpty && nameAr.isEmpty) {
                        setDialogState(() => errorText = l10n.requiredField);
                        return;
                      }
                      // 0 means unlimited picks (same as POS/customer).
                      if (maxSel == null || maxSel < 0) {
                        setDialogState(
                          () => errorText = l10n.modifierMaxInvalid,
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        final client = Supabase.instance.client;
                        final row = {
                          'name': name,
                          'name_ar': nameAr,
                          'is_required': required,
                          'max_selections': maxSel,
                        };
                        if (group == null) {
                          row['product_id'] = widget.productId;
                          row['sort_order'] = _groups.length;
                          await client
                              .from('product_modifier_groups')
                              .insert(row);
                        } else {
                          await client
                              .from('product_modifier_groups')
                              .update(row)
                              .eq('id', group['id'] as String);
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (_) {
                        setDialogState(() {
                          saving = false;
                          errorText = l10n.productSaveFailed;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _load();
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.delete),
        content: Text((group['name_ar'] ?? group['name'] ?? '').toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorLight,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final client = Supabase.instance.client;
      await client
          .from('product_modifier_options')
          .delete()
          .eq('group_id', group['id'] as String);
      await client
          .from('product_modifier_groups')
          .delete()
          .eq('id', group['id'] as String);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
      }
      return;
    }
    await _load();
  }

  Future<void> _editOption(
    Map<String, dynamic> group, [
    Map<String, dynamic>? option,
  ]) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: option?['name']?.toString());
    final nameArCtrl = TextEditingController(
      text: option?['name_ar']?.toString(),
    );
    final priceCtrl = TextEditingController(
      text: '${(option?['price_adjustment'] as num?)?.toDouble() ?? 0}',
    );
    var saving = false;
    String? errorText;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.modifierOptionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.modifierNameEn),
              ),
              TextField(
                controller: nameArCtrl,
                decoration: InputDecoration(labelText: l10n.modifierNameAr),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.modifierPriceAdjustment,
                ),
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: AppColors.errorLight),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final nameAr = nameArCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text.trim());
                      if ((name.isEmpty && nameAr.isEmpty) || price == null) {
                        setDialogState(() => errorText = l10n.requiredField);
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      try {
                        final client = Supabase.instance.client;
                        final row = {
                          'name': name,
                          'name_ar': nameAr,
                          'price_adjustment': price,
                        };
                        if (option == null) {
                          row['group_id'] = group['id'] as String;
                          row['sort_order'] =
                              (_options[group['id']] ?? const []).length;
                          await client
                              .from('product_modifier_options')
                              .insert(row);
                        } else {
                          await client
                              .from('product_modifier_options')
                              .update(row)
                              .eq('id', option['id'] as String);
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } catch (_) {
                        setDialogState(() {
                          saving = false;
                          errorText = l10n.productSaveFailed;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _load();
  }

  Future<void> _deleteOption(Map<String, dynamic> option) async {
    final l10n = AppLocalizations.of(context);
    try {
      await Supabase.instance.client
          .from('product_modifier_options')
          .delete()
          .eq('id', option['id'] as String);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
      }
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modifiersManage)),
      floatingActionButton: Padding(
        // Keep the FAB above the shell's floating bottom navigation bar.
        padding: const EdgeInsets.only(bottom: 96),
        child: FloatingActionButton.extended(
          onPressed: () => _editGroup(),
          icon: const Icon(Icons.add),
          label: Text(l10n.modifierAddGroup),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _groups.isEmpty
          ? Center(child: Text(l10n.modifierEmptyGroups))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                for (final g in _groups)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ((g['name_ar'] ?? '') as String).isNotEmpty
                                      ? g['name_ar'] as String
                                      : (g['name'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (g['is_required'] == true)
                                Text(
                                  l10n.posModifierRequired,
                                  style: const TextStyle(
                                    color: AppColors.errorLight,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editGroup(g),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteGroup(g),
                              ),
                            ],
                          ),
                          for (final o in _options[g['id']] ?? const [])
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                ((o['name_ar'] ?? '') as String).isNotEmpty
                                    ? o['name_ar'] as String
                                    : (o['name'] ?? '').toString(),
                              ),
                              subtitle: Text(
                                '+${((o['price_adjustment'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} '
                                '${l10n.currencySymbol}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editOption(g, o),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteOption(o),
                                  ),
                                ],
                              ),
                            ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () => _editOption(g),
                              icon: const Icon(Icons.add),
                              label: Text(l10n.modifierAddOption),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
