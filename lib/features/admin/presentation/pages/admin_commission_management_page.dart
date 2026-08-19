import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/services/admin/admin_providers.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class AdminCommissionManagementPage extends ConsumerStatefulWidget {
  const AdminCommissionManagementPage({super.key});

  @override
  ConsumerState<AdminCommissionManagementPage> createState() =>
      _AdminCommissionManagementPageState();
}

class _AdminCommissionManagementPageState
    extends ConsumerState<AdminCommissionManagementPage> {
  String? _savingKey;

  String _entityLabel(AppLocalizations l10n, String entityType, String key) {
    switch (entityType) {
      case 'account_type':
        return switch (key) {
          'customer' => l10n.commissionAccountCustomer,
          'admin' => l10n.commissionAccountAdmin,
          'driver' => l10n.commissionAccountDriver,
          'provider' => l10n.commissionAccountProvider,
          'merchant' => l10n.commissionAccountMerchant,
          _ => key,
        };
      case 'service_category':
        return switch (key) {
          'restaurant' => l10n.commissionCategoryRestaurant,
          'pharmacy' => l10n.commissionCategoryPharmacy,
          'grocery' => l10n.commissionCategoryGrocery,
          'marketplace' => l10n.commissionCategoryMarketplace,
          'plumbing' => l10n.commissionCategoryPlumbing,
          'electrical' => l10n.commissionCategoryElectrical,
          'cleaning' => l10n.commissionCategoryCleaning,
          _ => key,
        };
      default:
        return key.replaceAll('_', ' ');
    }
  }

  Future<void> _editRate({
    required String entityType,
    required String entityKey,
    required String currentLabel,
    required num currentRate,
    String? currentDescription,
  }) async {
    final l10n = AppLocalizations.of(context);
    final rateController = TextEditingController(
      text: currentRate.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''),
    );
    final descController = TextEditingController(text: currentDescription ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${l10n.commissionChange}: $currentLabel',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${l10n.commissionActive} %',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            TextField(
              controller: rateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: l10n.commissionNewRate,
                hintText: l10n.commissionRateHint,
                suffixText: '%',
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop({
              'rate': rateController.text,
              'description': descController.text.trim(),
            }),
            child: Text(l10n.commissionSave),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    final newRate = double.tryParse(result['rate'] as String);
    final description = (result['description'] as String?)?.trim();
    if (newRate == null || newRate < 0 || newRate > 100) return;

    final key = '$entityType/$entityKey';
    setState(() => _savingKey = key);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('set_commission_rate', params: {
        'p_entity_type': entityType,
        'p_entity_key': entityKey,
        'p_rate': newRate,
        'p_description': description?.isEmpty ?? true ? null : description,
      });
      if (mounted) {
        ref.invalidate(commissionRulesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.commissionRateUpdated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.commissionRateFailed}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingKey = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rulesAsync = ref.watch(commissionRulesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminCommissionManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(commissionRulesProvider),
          ),
        ],
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => Center(
          child: PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: l10n.errorLoading,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(commissionRulesProvider),
          ),
        ),
        data: (data) {
          final rules = (data['rules'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (rules.isEmpty) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.percent_rounded,
                title: l10n.adminCommissions,
                message: l10n.noResults,
              ),
            );
          }

          final groups = [
            ('account_type', l10n.commissionAccountGroup),
            ('service_type', l10n.commissionServiceTypeGroup),
            ('service_category', l10n.commissionServiceCategoryGroup),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (entityType, groupLabel) in groups)
                ..._buildGroup(
                  entityType: entityType,
                  groupLabel: groupLabel,
                  rules: rules,
                  scheme: scheme,
                  l10n: l10n,
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildGroup({
    required String entityType,
    required String groupLabel,
    required List<Map<String, dynamic>> rules,
    required ColorScheme scheme,
    required AppLocalizations l10n,
  }) {
    final groupRules = rules
        .where((r) => r['entity_type'] == entityType)
        .toList();
    if (groupRules.isEmpty) {
      return const [];
    }

    final byKey = <String, List<Map<String, dynamic>>>{};
    for (final rule in groupRules) {
      final key = rule['entity_key'] as String;
      byKey.putIfAbsent(key, () => []).add(rule);
    }

    return [
      AnimatedFadeIn(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            groupLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      for (final entry in byKey.entries) ...[
        AnimatedFadeIn(
          delay: const Duration(milliseconds: 60),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _entityLabel(l10n, entityType, entry.key),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (entry.value.any((r) => r['is_active'] == true))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l10n.commissionActive,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final rule in entry.value) _RuleRow(rule: rule),
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _savingKey == '$entityType/${entry.key}'
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: () {
                              final activeRules = entry.value
                                  .where((r) => r['is_active'] == true)
                                  .toList();
                              final active = activeRules.isNotEmpty
                                  ? activeRules.first
                                  : null;
                              _editRate(
                                entityType: entityType,
                                entityKey: entry.key,
                                currentLabel: _entityLabel(
                                  l10n,
                                  entityType,
                                  entry.key,
                                ),
                                currentRate: (active?['rate'] ??
                                        entry.value.first['rate'])
                                    as num,
                                currentDescription:
                                    active?['description'] as String?,
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text(l10n.commissionChange),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
    ];
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule});

  final Map<String, dynamic> rule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isActive = rule['is_active'] == true;
    final rate = (rule['rate'] as num).toStringAsFixed(2);
    final effectiveFrom = rule['effective_from'] as String?;
    final effectiveTo = rule['effective_to'] as String?;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.green : scheme.outlineVariant,
            ),
          ),
          Expanded(
            child: Text(
              '$rate%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isActive ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            [
              '${l10n.commissionEffectiveFrom} ${_formatDate(effectiveFrom)}',
              if (effectiveTo != null)
                '→ ${_formatDate(effectiveTo)}'
              else
                l10n.commissionNoExpiry,
            ].join(' '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
