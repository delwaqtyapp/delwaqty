import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class DeliveryCarRequestPage extends ConsumerStatefulWidget {
  const DeliveryCarRequestPage({super.key});

  @override
  ConsumerState<DeliveryCarRequestPage> createState() =>
      _DeliveryCarRequestPageState();
}

class _DeliveryCarRequestPageState extends ConsumerState<DeliveryCarRequestPage> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final pickup = _pickupController.text.trim();
    final dropoff = _dropoffController.text.trim();
    final phone = _phoneController.text.trim();
    if (pickup.isEmpty) {
      context.showAppSnackBar(l10n.deliverTo, isError: true);
      return;
    }
    if (dropoff.isEmpty) {
      context.showAppSnackBar(l10n.deliverTo, isError: true);
      return;
    }
    if (phone.isEmpty) {
      context.showAppSnackBar(l10n.customerPhone, isError: true);
      return;
    }
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) {
      context.showAppSnackBar(l10n.loginRequired, isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(serviceBookingRepositoryProvider).submitDeliveryCarRequest(
            pickupAddress: pickup,
            dropoffAddress: dropoff,
            phone: phone,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (!mounted) return;
      context.showAppSnackBar(l10n.deliveryCarRequested);
      context.go('/wallet');
    } catch (e) {
      if (!mounted) return;
      context.showAppSnackBar(l10n.somethingWentWrong, isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliveryCar)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_taxi_rounded, color: cs.primary, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.deliveryCarHint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pickupController,
            decoration: InputDecoration(
              labelText: l10n.pickupAddress,
              prefixIcon: const Icon(Icons.place_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _dropoffController,
            decoration: InputDecoration(
              labelText: l10n.dropoffAddress,
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.note,
              prefixIcon: const Icon(Icons.notes_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(l10n.submitRequest),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.myRequests,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          const _MyRequestsList(),
        ],
      ),
    );
  }
}

class _MyRequestsList extends ConsumerWidget {
  const _MyRequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final future = ref.watch(myDeliveryCarRequestsProvider);
    return future.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (requests) {
        if (requests.isEmpty) {
          return Text(
            l10n.noRequestsYet,
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          children: [
            for (final r in requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['pickup_address']} ← ${r['dropoff_address']}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${l10n.statusLabel}: ${_statusLabel(l10n, r['status'] as String)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _statusColor(cs, r['status'] as String),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
        'pending' => l10n.statusPending,
        'reviewing' => l10n.statusReviewing,
        'approved' => l10n.statusApproved,
        'rejected' => l10n.statusRejected,
        'completed' => l10n.statusCompleted,
        'cancelled' => l10n.statusCancelled,
        _ => status,
      };

  Color _statusColor(ColorScheme cs, String status) => switch (status) {
        'pending' => Colors.orange,
        'reviewing' => Colors.blue,
        'approved' => Colors.green,
        'rejected' => cs.error,
        'completed' => Colors.teal,
        _ => cs.onSurfaceVariant,
      };
}