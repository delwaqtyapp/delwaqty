import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/merchant/merchant_module.dart';
import 'package:delwaqty/features/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/restaurant/domain/entities/offer.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/theme/app_colors.dart';

final _merchantIdProvider = Provider<String>((_) => 'current-merchant-id');

final _offersProvider = FutureProvider<List<Offer>>((ref) async {
  final repo = ref.watch(offerRepositoryProvider);
  final merchantId = ref.watch(_merchantIdProvider);
  return repo.getOffers(merchantId);
});

class MerchantOffersPage extends ConsumerStatefulWidget {
  const MerchantOffersPage({super.key});

  @override
  ConsumerState<MerchantOffersPage> createState() => _MerchantOffersPageState();
}

class _MerchantOffersPageState extends ConsumerState<MerchantOffersPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offersAsync = ref.watch(_offersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageOffers),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_offersProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOfferForm(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.addOffer),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchOffers,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: offersAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ShimmerCard(height: 120),
                ),
              ),
              error: (e, _) => Center(
                child: PremiumEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: l10n.error,
                  message: l10n.errorLoading,
                  actionLabel: l10n.retry,
                  onAction: () => ref.invalidate(_offersProvider),
                ),
              ),
              data: (offers) {
                final filtered = _searchQuery.isEmpty
                    ? offers
                    : offers.where((o) {
                        final title = o.title.toLowerCase();
                        return title.contains(_searchQuery.toLowerCase());
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: PremiumEmptyState(
                      icon: Icons.local_offer_outlined,
                      title: l10n.noOffersYet,
                      message: _searchQuery.isNotEmpty
                          ? l10n.noResultsFound
                          : l10n.noOffersMessage,
                      actionLabel: _searchQuery.isEmpty ? l10n.addOffer : null,
                      onAction: _searchQuery.isEmpty
                          ? () => _showOfferForm(context)
                          : null,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_offersProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final offer = filtered[index];
                      return AnimatedFadeIn(
                        delay: Duration(milliseconds: index * 50),
                        child: _OfferCard(
                          offer: offer,
                          onEdit: () => _showOfferForm(context, offer: offer),
                          onDelete: () => _confirmDelete(context, offer),
                          onToggleActive: () => _toggleActive(offer),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showOfferForm(BuildContext context, {Offer? offer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OfferFormSheet(
        merchantId: ref.read(_merchantIdProvider),
        offer: offer,
        onSaved: () {
          ref.invalidate(_offersProvider);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Offer offer) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteOffer),
        content: Text(l10n.confirmDeleteOffer),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteOffer(offer);
    }
  }

  Future<void> _deleteOffer(Offer offer) async {
    final repo = ref.read(offerRepositoryProvider);
    await repo.deleteOffer(offer.id);
    ref.invalidate(_offersProvider);
    if (mounted) {
      context.showAppSnackBar(
        AppLocalizations.of(context).offerDeleted,
      );
    }
  }

  Future<void> _toggleActive(Offer offer) async {
    final repo = ref.read(offerRepositoryProvider);
    final updated = offer.copyWith(isActive: !offer.isActive);
    await repo.updateOffer(updated);
    ref.invalidate(_offersProvider);
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final Offer offer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final isPercentage = offer.discountType == 'percentage';
    final discountText = isPercentage
        ? '${offer.discountValue.toStringAsFixed(0)}% OFF'
        : '${offer.discountValue.toStringAsFixed(0)} ${l10n.sar} OFF';

    final isExpired =
        offer.expiresAt != null && offer.expiresAt!.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: offer.isActive
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isExpired
                      ? [Colors.grey.shade300, Colors.grey.shade200]
                      : [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.8),
                        ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    color: Colors.white.withOpacity(0.9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    discountText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isExpired) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.offerExpired,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (offer.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      offer.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatusChip(
                        label: offer.isActive ? l10n.active : l10n.inactive,
                        isActive: offer.isActive,
                      ),
                      const SizedBox(width: 8),
                      if (offer.minimumOrder > 0)
                        Text(
                          l10n.minOrderRequired(
                            offer.minimumOrder.toStringAsFixed(0),
                            l10n.sar,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onToggleActive,
                          icon: Icon(
                            offer.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 18,
                          ),
                          label: Text(
                            offer.isActive
                                ? l10n.deactivateOffer
                                : l10n.activateOffer,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: l10n.editOffer,
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                        tooltip: l10n.deleteOffer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.successLight
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isActive
                            ? AppColors.successDark
                            : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _OfferFormSheet extends ConsumerStatefulWidget {
  const _OfferFormSheet({
    required this.merchantId,
    this.offer,
    required this.onSaved,
  });

  final String merchantId;
  final Offer? offer;
  final VoidCallback onSaved;

  @override
  ConsumerState<_OfferFormSheet> createState() => _OfferFormSheetState();
}

class _OfferFormSheetState extends ConsumerState<_OfferFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _discountValueController;
  late final TextEditingController _minimumOrderController;
  late final TextEditingController _maxDiscountController;

  String _discountType = 'percentage';
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final offer = widget.offer;
    _titleController = TextEditingController(text: offer?.title ?? '');
    _descriptionController =
        TextEditingController(text: offer?.description ?? '');
    _discountValueController =
        TextEditingController(text: offer?.discountValue.toString() ?? '');
    _minimumOrderController =
        TextEditingController(text: offer?.minimumOrder.toString() ?? '');
    _maxDiscountController =
        TextEditingController(text: offer?.maximumDiscount?.toString() ?? '');
    _discountType = offer?.discountType ?? 'percentage';
    _isActive = offer?.isActive ?? true;
    _startDate = offer?.startsAt;
    _endDate = offer?.expiresAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _minimumOrderController.dispose();
    _maxDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEditing = widget.offer != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? l10n.editOffer : l10n.addOffer,
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
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.offerTitle,
                        hintText: l10n.enterOfferTitle,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? l10n.fieldRequired : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.offerDescription,
                        hintText: l10n.enterOfferDescription,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _discountType,
                      decoration: InputDecoration(
                        labelText: l10n.discountType,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'percentage',
                          child: Text(l10n.percentage),
                        ),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text(l10n.fixedAmount),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _discountType = v);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _discountValueController,
                      decoration: InputDecoration(
                        labelText: l10n.discountValue,
                        hintText: l10n.enterDiscountValue,
                        border: const OutlineInputBorder(),
                        suffixText: _discountType == 'percentage' ? '%' : l10n.sar,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return l10n.fieldRequired;
                        if (double.tryParse(v) == null) return l10n.fieldRequired;
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _minimumOrderController,
                      decoration: InputDecoration(
                        labelText: l10n.minimumOrder,
                        hintText: l10n.enterMinimumOrder,
                        border: const OutlineInputBorder(),
                        prefixText: '${l10n.sar} ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _maxDiscountController,
                      decoration: InputDecoration(
                        labelText: l10n.maximumDiscount,
                        hintText: l10n.enterMaximumDiscount,
                        border: const OutlineInputBorder(),
                        prefixText: '${l10n.sar} ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: l10n.startDate,
                            date: _startDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() => _startDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: l10n.endDate,
                            date: _endDate,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _endDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: _startDate ?? DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.activateOffer),
                      subtitle: Text(
                        _isActive ? l10n.active : l10n.inactive,
                      ),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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

    final repo = ref.read(offerRepositoryProvider);
    final offer = Offer(
      id: widget.offer?.id ?? '',
      merchantId: widget.merchantId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      discountType: _discountType,
      discountValue: double.parse(_discountValueController.text),
      minimumOrder: double.tryParse(_minimumOrderController.text) ?? 0,
      maximumDiscount: double.tryParse(_maxDiscountController.text),
      isActive: _isActive,
      startsAt: _startDate,
      expiresAt: _endDate,
      createdAt: widget.offer?.createdAt ?? DateTime.now(),
    );

    if (widget.offer != null) {
      await repo.updateOffer(offer);
    } else {
      await repo.createOffer(offer);
    }

    setState(() => _saving = false);
    widget.onSaved();
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          date != null
              ? '${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}'
              : '--/--/----',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
