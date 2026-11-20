import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/features/customer/ride/presentation/widgets/ride_map.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/services/maps/maps_service.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startWithOtp(String driverId, DeliveryOrder order) async {
    if (!order.otpRequired) {
      await _run(
        () => ref
            .read(deliveryRepositoryProvider)
            .startDelivery(order.id, driverId, order.pickupOtp ?? ''),
      );
      return;
    }

    final controller = TextEditingController(text: order.pickupOtp ?? '');
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
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
    if (otp == null || otp.isEmpty) return;
    await _run(
      () => ref
          .read(deliveryRepositoryProvider)
          .startDelivery(order.id, driverId, otp),
    );
  }

  Future<void> _confirmAndCancel(String orderId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmCancelDeliveryTitle),
        content: Text(l10n.confirmCancelDeliveryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ref.read(deliveryRepositoryProvider).cancelDelivery(
            orderId,
            reason: 'cancelled_by_driver',
            byDriver: true,
          ),
    );
  }

  Future<void> _confirmAndComplete(String orderId, String driverId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.completeDelivery),
        content: Text(l10n.areYouSure),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ref
          .read(deliveryRepositoryProvider)
          .completeDelivery(orderId, driverId),
    );
  }

  String? _resolveCustomerPhone(DeliveryOrder order) {
    final direct = order.recipientPhone?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final notes = order.dropoffNotes;
    if (notes != null && notes.isNotEmpty) {
      final match = RegExp(r'(\+?\d[\d\s\-]{7,14}\d)').firstMatch(notes);
      if (match != null) {
        return match.group(0)?.replaceAll(RegExp(r'[\s\-]'), '');
      }
    }
    return null;
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (!await canLaunchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).somethingWentWrong),
            ),
          );
        }
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    var digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('01') && digits.length == 11) {
      digits = '2$digits';
    }
    final uri = Uri.parse('https://wa.me/$digits');
    try {
      if (!await canLaunchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).somethingWentWrong),
            ),
          );
        }
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(appErrorText(context, e))),
        );
      }
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final orderAsync = ref.watch(deliveryOrderByIdProvider(widget.id));
    final authState = ref.watch(authStateProvider);
    final userId = authState is AuthAuthenticated ? authState.user.id : null;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.deliveryDetails)),
        body: Center(child: Text(l10n.pleaseLogIn)),
      );
    }

    final profileAsync = ref.watch(driverProfileProvider(userId));

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.deliveryDetails)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.deliveryDetails)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(appErrorText(context, e)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(driverProfileProvider(userId)),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.deliveryDetails)),
            body: Center(child: Text(l10n.becomeADriver)),
          );
        }
        final driverId = profile.id;
        final livePosition = ref.watch(driverLivePositionProvider(driverId));

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
        error: (e, _) => Center(child: Text(appErrorText(context, e))),
        data: (order) {
          if (order == null) {
            return Center(child: Text(l10n.orderNotFound));
          }
          final status = order.status;
          final canCancel = status != 'completed' && status != 'cancelled';
          final customerPhone = _resolveCustomerPhone(order);
          final pickupLatLng =
              LatLng(order.pickupLatitude, order.pickupLongitude);
          final dropoffLatLng =
              LatLng(order.dropoffLatitude, order.dropoffLongitude);
          final driverLatLng = livePosition != null
              ? LatLng(livePosition.latitude, livePosition.longitude)
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Live Delivery Map Section
              Text(
                l10n.liveDeliveryMapTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: RideMap(
                  pickup: pickupLatLng,
                  dropoff: dropoffLatLng,
                  driver: driverLatLng,
                  height: 240,
                ),
              ),
              const SizedBox(height: 12),
              // 1-Tap Navigation Buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        ref.read(mapsServiceProvider).openNavigation(
                              GeoLocation(
                                latitude: order.pickupLatitude,
                                longitude: order.pickupLongitude,
                              ),
                            );
                      },
                      icon: const Icon(Icons.storefront_rounded, size: 18),
                      label: Text(
                        l10n.navigateToPickup,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(mapsServiceProvider).openNavigation(
                              GeoLocation(
                                latitude: order.dropoffLatitude,
                                longitude: order.dropoffLongitude,
                              ),
                            );
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: Text(
                        l10n.navigateToCustomer,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              if (customerPhone != null && customerPhone.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _callPhone(customerPhone),
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: Text(
                          l10n.callCustomer,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.successLight,
                        ),
                        onPressed: () => _openWhatsApp(customerPhone),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: Text(
                          l10n.whatsappCustomer,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              // Order Details Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(l10n.status, status),
                      _row(l10n.type, order.serviceType),
                      if (order.merchantName != null &&
                          order.merchantName!.isNotEmpty)
                        _row(l10n.merchant, order.merchantName!),
                      if (order.recipientName != null &&
                          order.recipientName!.isNotEmpty)
                        _row(l10n.fullName, order.recipientName!),
                      if (customerPhone != null && customerPhone.isNotEmpty)
                        _row(l10n.orderCustomerPhone, customerPhone),
                      _row(l10n.pickupPointLabel, order.pickupAddress),
                      if (order.pickupNotes != null &&
                          order.pickupNotes!.isNotEmpty)
                        _row(l10n.deliveryNotesLabel, order.pickupNotes!),
                      _row(l10n.dropoffPointLabel, order.dropoffAddress),
                      if (order.dropoffNotes != null &&
                          order.dropoffNotes!.isNotEmpty)
                        _row(l10n.orderSpecialNotes, order.dropoffNotes!),
                      if (order.itemsSummary != null &&
                          order.itemsSummary!.isNotEmpty)
                        _row(l10n.orderItemsSummary, order.itemsSummary!),
                      if (order.fare != null)
                        _row(
                          l10n.fare,
                          '${order.fare!.toStringAsFixed(0)} ${order.currency}',
                        ),
                      if (order.distance != null)
                        _row(
                          l10n.distance,
                          l10n.expectedKm(
                            order.distance?.toStringAsFixed(1) ?? '0',
                          ),
                        ),
                      if (order.estimatedMinutes != null)
                        _row(
                          l10n.estimatedTime,
                          l10n.estimatedMinutesValue(order.estimatedMinutes!),
                        ),
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
                      : () => _run(
                            () => ref
                                .read(deliveryRepositoryProvider)
                                .acceptDeliveryRequest(order.id, driverId),
                          ),
                  child: Text(l10n.accept),
                ),
              if (status == 'matched')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => ref
                                .read(deliveryRepositoryProvider)
                                .driverArrivedAtPickup(order.id, driverId),
                          ),
                  child: Text(l10n.arriveAtPickup),
                ),
              if (status == 'arrived')
                FilledButton(
                  onPressed:
                      _busy ? null : () => _startWithOtp(driverId, order),
                  child: Text(l10n.startDelivery),
                ),
              if (status == 'inTrip')
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _confirmAndComplete(order.id, driverId),
                  child: Text(l10n.completeDelivery),
                ),
              if (canCancel) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _confirmAndCancel(order.id),
                  child: Text(l10n.cancel),
                ),
              ],
            ],
          );
        },
      ),
    );
      },
    );
  }
}
