import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';

final _deliveryCarRequestsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    final rows = await Supabase.instance.client
        .from('delivery_car_requests')
        .select('*, user_id')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  },
);

class AdminDeliveryCarRequestsPage extends ConsumerWidget {
  const AdminDeliveryCarRequestsPage({super.key});

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String id,
    String status,
  ) async {
    await Supabase.instance.client
        .from('delivery_car_requests')
        .update({'status': status, 'reviewed_at': DateTime.now().toIso8601String()})
        .eq('id', id);
    ref.invalidate(_deliveryCarRequestsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(_deliveryCarRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDeliveryCarRequests)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PremiumEmptyState(
          icon: Icons.error_outline,
          title: l10n.error,
          message: '$e',
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.local_taxi_rounded,
              title: l10n.noRequestsYet,
              message: l10n.nearbyEmptyHint,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_deliveryCarRequestsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final r = requests[index];
                final status = r['status'] as String? ?? 'pending';
                return AnimatedFadeIn(
                  delay: Duration(milliseconds: index * 40),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _StatusChip(status: status),
                              const Spacer(),
                              Text(
                                _date(r['created_at']),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _row(context, Icons.place_outlined,
                              r['pickup_address'] ?? ''),
                          const SizedBox(height: 6),
                          _row(context, Icons.location_on_outlined,
                              r['dropoff_address'] ?? ''),
                          const SizedBox(height: 6),
                          _row(context, Icons.phone_outlined,
                              r['phone'] ?? ''),
                          if (r['note'] != null && (r['note'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _row(context, Icons.notes_rounded,
                                  r['note'] as String),
                            ),
                          const SizedBox(height: 10),
                          if (status == 'pending' || status == 'reviewing')
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _updateStatus(
                                        context, ref, r['id'] as String,
                                        status == 'pending' ? 'reviewing' : 'rejected'),
                                    child: Text(
                                      status == 'pending'
                                          ? l10n.adminStartReview
                                          : l10n.statusRejected,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => _updateStatus(context, ref,
                                        r['id'] as String, 'approved'),
                                    child: Text(l10n.statusApproved),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              '${l10n.statusLabel}: ${_statusLabel(l10n, status)}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _date(dynamic iso) {
    final dt = DateTime.tryParse(iso?.toString() ?? '');
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => Colors.orange,
      'reviewing' => Colors.blue,
      'approved' => Colors.green,
      'rejected' => Theme.of(context).colorScheme.error,
      'completed' => Colors.teal,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}