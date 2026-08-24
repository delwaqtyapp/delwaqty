import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
        title: const Text('ادخل رمز التأكيد OTP'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'OTP'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('تأكيد')),
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
    final orderAsync = ref.watch(deliveryOrderByIdProvider(widget.id));
    final authState = ref.watch(authStateProvider);
    final driverId =
        authState is AuthAuthenticated ? authState.user.id : '';

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل التوصيل')),
      body: orderAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            ShimmerCard(height: 120),
            SizedBox(height: 12),
            ShimmerCard(height: 120),
          ],
        ),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('الطلب غير موجود'));
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
                      _row('الحالة', status),
                      _row('النوع', order.serviceType),
                      if (order.merchantName != null)
                        _row('التاجر', order.merchantName!),
                      _row('الاستلام', order.pickupAddress),
                      _row('التسليم', order.dropoffAddress),
                      if (order.itemsSummary != null)
                        _row('العناصر', order.itemsSummary!),
                      if (order.fare != null)
                        _row('الأجرة', '${order.fare} ${order.currency}'),
                      if (order.distance != null)
                        _row('المسافة', '${order.distance} كم'),
                      if (order.estimatedMinutes != null)
                        _row('الوقت المتوقع',
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
                  child: const Text('قبول الطلب'),
                ),
              if (status == 'matched')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref
                          .read(deliveryRepositoryProvider)
                          .driverArrivedAtPickup(order.id, driverId)),
                  child: const Text('وصلت لنقطة الاستلام'),
                ),
              if (status == 'arrived')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _startWithOtp(driverId, order.id),
                  child: const Text('بدء التوصيل'),
                ),
              if (status == 'inTrip')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref
                          .read(deliveryRepositoryProvider)
                          .completeDelivery(order.id, driverId)),
                  child: const Text('إتمام التوصيل'),
                ),
              if (canCancel) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref
                          .read(deliveryRepositoryProvider)
                          .cancelDelivery(order.id,
                              reason: 'cancelled_by_driver')),
                  child: const Text('إلغاء'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
