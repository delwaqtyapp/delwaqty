import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/restaurant/domain/entities/reservation.dart';
import 'package:delwaqty/features/restaurant/domain/entities/branch.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/shared/widgets/app_snackbar.dart';

final _branchesProvider = FutureProvider.family<List<Branch>, String>((ref, merchantId) async {
  final repo = ref.watch(branchRepositoryProvider);
  return repo.getBranches(merchantId);
});

final _slotsProvider = FutureProvider.family<List<ReservationSlot>, ({String merchantId, DateTime date, int partySize, String? branchId})>((ref, params) async {
  final repo = ref.watch(reservationRepositoryProvider);
  return repo.getAvailableSlots(
    merchantId: params.merchantId,
    date: params.date,
    partySize: params.partySize,
    branchId: params.branchId,
  );
});

class RestaurantReservationPage extends ConsumerStatefulWidget {
  const RestaurantReservationPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  ConsumerState<RestaurantReservationPage> createState() => _RestaurantReservationPageState();
}

class _RestaurantReservationPageState extends ConsumerState<RestaurantReservationPage> {
  DateTime _selectedDate = DateTime.now();
  int _partySize = 2;
  Branch? _selectedBranch;
  ReservationSlot? _selectedSlot;
  final _specialRequestsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _specialRequestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(_branchesProvider(widget.merchantId));
    final slotsAsync = ref.watch(_slotsProvider((
      merchantId: widget.merchantId,
      date: _selectedDate,
      partySize: _partySize,
      branchId: _selectedBranch?.id,
    )));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reserveATable)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 100),
              child: _buildDateSelector(context, l10n, theme),
            ),
            const SizedBox(height: 20),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 200),
              child: _buildPartySizeSelector(context, l10n, theme),
            ),
            const SizedBox(height: 20),
            branchesAsync.when(
              data: (branches) {
                if (branches.length <= 1) return const SizedBox.shrink();
                return AnimatedFadeIn(
                  delay: const Duration(milliseconds: 300),
                  child: _buildBranchSelector(context, l10n, theme, branches),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 350),
              child: _buildSpecialRequests(context, l10n, theme),
            ),
            const SizedBox(height: 20),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 400),
              child: Text(
                l10n.availableSlots,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 450),
              child: slotsAsync.when(
                data: (slots) {
                  if (slots.isEmpty) {
                    return PremiumEmptyState(
                      icon: Icons.event_busy_outlined,
                      title: l10n.noSlotsAvailable,
                      message: l10n.tryDifferentDate,
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: slots.where((s) => s.isAvailable).map((slot) {
                      final isSelected = _selectedSlot?.time == slot.time;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSlot = slot),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${slot.time.hour.toString().padLeft(2, '0')}:${slot.time.minute.toString().padLeft(2, '0')}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isSelected ? theme.colorScheme.onPrimary : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${slot.capacity} ${l10n.guests}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary.withOpacity(0.8)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: AppLoaderCircular()),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedFadeIn(
              delay: const Duration(milliseconds: 500),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedSlot == null || _isSubmitting ? null : _submitReservation,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(l10n.confirmReservation),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final dates = List.generate(7, (i) => DateTime.now().add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectDate,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = dates[index];
              final isSelected = _isSameDay(date, _selectedDate);
              final dayName = index == 0 ? l10n.today : index == 1 ? l10n.tomorrow : _getDayName(date.weekday);

              return GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = date;
                  _selectedSlot = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isSelected ? theme.colorScheme.onPrimary : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPartySizeSelector(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.partySize,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _CircleButton(
              icon: Icons.remove,
              onTap: _partySize > 1 ? () => setState(() { _partySize--; _selectedSlot = null; }) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    '$_partySize',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    l10n.guests,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _CircleButton(
              icon: Icons.add,
              onTap: _partySize < 20 ? () => setState(() { _partySize++; _selectedSlot = null; }) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBranchSelector(BuildContext context, AppLocalizations l10n, ThemeData theme, List<Branch> branches) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.branches,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: branches.map((branch) {
            final isSelected = _selectedBranch?.id == branch.id;
            return ChoiceChip(
              label: Text(branch.name),
              selected: isSelected,
              onSelected: (_) => setState(() {
                _selectedBranch = branch;
                _selectedSlot = null;
              }),
              selectedColor: theme.colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSpecialRequests(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.specialRequests,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _specialRequestsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.specialRequestsHint,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _getDayName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  Future<void> _submitReservation() async {
    if (_selectedSlot == null) return;
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(reservationRepositoryProvider);
      await repo.createReservation(Reservation(
        id: '',
        userId: '',
        merchantId: widget.merchantId,
        branchId: _selectedBranch?.id,
        partySize: _partySize,
        reservationTime: _selectedSlot!.time,
        specialRequests: _specialRequestsController.text.isNotEmpty
            ? _specialRequestsController.text
            : null,
        tableNumber: _selectedSlot!.tableNumber,
        createdAt: DateTime.now(),
      ));

      if (mounted) {
        AppSnackbar.success(context, message: AppLocalizations.of(context).reservationConfirmed);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, message: AppLocalizations.of(context).error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onTap != null
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
        ),
      ),
    );
  }
}
