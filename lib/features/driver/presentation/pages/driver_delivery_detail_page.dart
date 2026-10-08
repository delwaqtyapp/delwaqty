import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

class DriverDeliveryDetailPage extends ConsumerStatefulWidget {
  const DriverDeliveryDetailPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DriverDeliveryDetailPage> createState() =>
      _DriverDeliveryDetailPageState();
}

class _DriverDeliveryDetailPageState
    extends ConsumerState<DriverDeliveryDetailPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ref.invalidate(deliveryOrderByIdProvider(widget.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context).error)),
            );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startWithOtp(String driverId, String rideId) async {
    final controller = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).otpPrompt),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'OTP'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context).cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(AppLocalizations.of(context).confirm)),
        ],
      ),
    );
    if (otp == null || otp.isEmpty) return;
    await _run(() => ref
        .read(deliveryRepositoryProvider)
        .startDelivery(rideId, driverId, otp));
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(value)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderAsync = ref.watch(deliveryOrderByIdProvider(widget.id));
    final authState = ref.watch(authStateProvider);
    final userId =
        authState is AuthAuthenticated ? authState.user.id : null;

    // Every lifecycle RPC (accept_ride_request / driver_arrive /
    // start_trip / complete_delivery) opens with
    //   SELECT user_id INTO v_owner FROM drivers WHERE id = p_driver_id
    // and rejects the call when p_driver_id is not a drivers.id.
    // Passing the auth uid made Accept / Arrive / Start / Complete all
    // fail with 'forbidden', so the whole delivery loop was dead from
    // this page.
    final profileAsync = userId == null
        ? null
        : ref.watch(driverProfileProvider(userId));
    final driverId = profileAsync?.asData?.value?.id ?? '';

    if (userId != null && driverId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.deliveryDetails)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deliveryDetails)),
      body: orderAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerCard(),
            SizedBox(height: 12),
            ShimmerCard(),
          ],
        ),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (order) {
          if (order == null) {
            return Center(child: Text(l10n.orderNotFound));
          }
          final status = order.status;
          final canCancel =
              status != 'completed' && status != 'cancelled';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(l10n.status, status),
                      _row(l10n.type, order.serviceType),
                      if (order.merchantName != null)
                        _row(l10n.merchant, order.merchantName!),
                      _row(l10n.pickup, order.pickupAddress),
                      _row(l10n.dropoff, order.dropoffAddress),
                      if (order.itemsSummary != null)
                        _row(l10n.items, order.itemsSummary!),
                      if (order.fare != null)
                        _row(l10n.fare, '${order.fare} ${order.currency}'),
                      if (order.distance != null)
                        _row(l10n.distance, l10n.expectedKm(order.distance?.toStringAsFixed(1) ?? '0')),
                      if (order.estimatedMinutes != null)
                        _row(l10n.estimatedTime,
                            '${order.estimatedMinutes} دقيقة'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (status == 'searching' || status == 'requested')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref
                          .read(deliveryRepositoryProvider)
                          .acceptDeliveryRequest(order.id, driverId)),
                  child: Text(l10n.accept),
                ),
              if (status == 'matched')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref
                          .read(deliveryRepositoryProvider)
                          .driverArrivedAtPickup(order.id, driverId)),
                  child: Text(l10n.arriveAtPickup),
                ),
              if (status == 'arrived')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _startWithOtp(driverId, order.id),
                  child: Text(l10n.startDelivery),
                ),
              if (status == 'inTrip')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref
                          .read(deliveryRepositoryProvider)
                          .completeDelivery(order.id, driverId)),
                  child: Text(l10n.completeDelivery),
                ),
              if (canCancel) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref
                          .read(deliveryRepositoryProvider)
                          .cancelDelivery(order.id,
                              reason: 'cancelled_by_driver',
                              byDriver: true)),
                  child: Text(AppLocalizations.of(context).cancel),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
