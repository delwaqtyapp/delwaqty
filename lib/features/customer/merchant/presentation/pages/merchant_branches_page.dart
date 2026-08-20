import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/customer/merchant/merchant_module.dart';
import 'package:delwaqty/features/customer/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/customer/restaurant/domain/entities/branch.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_spacing.dart';
import 'package:delwaqty/shared/widgets/design/premium_card.dart';

final _merchantIdProvider = Provider<String>((_) => 'current-merchant-id');

final _branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final repo = ref.watch(branchRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  return repo.getBranches(merchantId);
});

class MerchantBranchesPage extends ConsumerStatefulWidget {
  const MerchantBranchesPage({super.key});

  @override
  ConsumerState<MerchantBranchesPage> createState() =>
      _MerchantBranchesPageState();
}

class _MerchantBranchesPageState extends ConsumerState<MerchantBranchesPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final branchesAsync = ref.watch(_branchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.branches),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_branchesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBranchForm(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.addBranch),
      ),
      body: branchesAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: 5,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerCard(height: 100),
          ),
        ),
        error: (e, _) => Center(
          child: PremiumEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.error,
            message: l10n.errorLoading,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(_branchesProvider),
          ),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.store_outlined,
                title: l10n.noBranches,
                message: l10n.noBranches,
                actionLabel: l10n.addBranch,
                onAction: () => _showBranchForm(context),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_branchesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                80,
              ),
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final branch = branches[index];
                return AnimatedFadeIn(
                  delay: Duration(milliseconds: index * 50),
                  child: _BranchCard(
                    branch: branch,
                    onTap: () => _showBranchForm(context, branch: branch),
                    onDelete: () => _confirmDelete(context, branch),
                    onToggleActive: () => _toggleActive(branch),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showBranchForm(BuildContext context, {Branch? branch}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BranchFormSheet(
        merchantId: ref.read(_merchantIdProvider),
        branch: branch,
        onSaved: () {
          ref.invalidate(_branchesProvider);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Branch branch) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('${l10n.areYouSureYouWantToDelete} ${branch.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteBranch(branch);
    }
  }

  Future<void> _deleteBranch(Branch branch) async {
    final repo = ref.read(branchRepositoryProvider);
    await repo.deleteBranch(branch.id);
    ref.invalidate(_branchesProvider);
    if (mounted) {
      context.showAppSnackBar('Branch deleted');
    }
  }

  Future<void> _toggleActive(Branch branch) async {
    final repo = ref.read(branchRepositoryProvider);
    final updated = branch.copyWith(isActive: !branch.isActive);
    await repo.updateBranch(updated);
    ref.invalidate(_branchesProvider);
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.onTap,
    required this.onDelete,
    required this.onToggleActive,
  });

  final Branch branch;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(branch.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onError,
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PremiumCard(
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      branch.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (branch.isPrimary)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Primary',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.brandPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Switch(
                    value: branch.isActive,
                    onChanged: (_) => onToggleActive(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              if (branch.address != null && branch.address!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        branch.address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (branch.phone != null && branch.phone!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      branch.phone!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchFormSheet extends ConsumerStatefulWidget {
  const _BranchFormSheet({
    required this.merchantId,
    this.branch,
    required this.onSaved,
  });

  final String merchantId;
  final Branch? branch;
  final VoidCallback onSaved;

  @override
  ConsumerState<_BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends ConsumerState<_BranchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  bool _isPrimary = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final branch = widget.branch;
    _nameController = TextEditingController(text: branch?.name ?? '');
    _addressController = TextEditingController(text: branch?.address ?? '');
    _phoneController = TextEditingController(text: branch?.phone ?? '');
    _latitudeController = TextEditingController(
      text: branch?.latitude?.toString() ?? '',
    );
    _longitudeController = TextEditingController(
      text: branch?.longitude?.toString() ?? '',
    );
    _isPrimary = branch?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.branch != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSheet),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? l10n.edit : l10n.addBranch,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.branchName,
                        hintText: 'Enter branch name',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? l10n.fieldRequired : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: l10n.address,
                        hintText: 'Enter branch address',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: l10n.phone,
                        hintText: 'Enter phone number',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              hintText: '0.0',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              hintText: '0.0',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SwitchListTile(
                      title: const Text('Primary Branch'),
                      subtitle: Text(
                        _isPrimary ? 'Yes' : 'No',
                      ),
                      value: _isPrimary,
                      onChanged: (v) => setState(() => _isPrimary = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.saveChanges),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final repo = ref.read(branchRepositoryProvider);
    final branch = Branch(
      id: widget.branch?.id ?? '',
      merchantId: widget.merchantId,
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      latitude: double.tryParse(_latitudeController.text),
      longitude: double.tryParse(_longitudeController.text),
      isActive: widget.branch?.isActive ?? true,
      isPrimary: _isPrimary,
      createdAt: widget.branch?.createdAt ?? DateTime.now(),
    );

    if (widget.branch != null) {
      await repo.updateBranch(branch);
    } else {
      await repo.createBranch(branch);
    }

    setState(() => _saving = false);
    widget.onSaved();
  }
}
