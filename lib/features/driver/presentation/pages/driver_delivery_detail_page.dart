import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/delivery_handoff_button.dart';
import 'package:delwaqty/shared/widgets/delivery_incident_dialog.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/geo_location.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/cash_collection.dart';
import 'package:delwaqty/features/customer/delivery/domain/entities/delivery_order.dart';
import 'package:delwaqty/features/customer/delivery/presentation/providers/delivery_providers.dart';
import 'package:delwaqty/features/customer/driver/presentation/providers/dispatch_providers.dart';
import 'package:delwaqty/features/customer/ride/presentation/widgets/ride_map.dart';
import 'package:delwaqty/features/driver/driver_module.dart';
import 'package:delwaqty/features/driver/presentation/widgets/cash_collection_card.dart';
import 'package:delwaqty/shared/widgets/unconfirmed_phone_banner.dart';
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

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ref.invalidate(deliveryOrderByIdProvider(widget.id));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startWithOtp(String driverId, DeliveryOrder order) async {
    final otp = await showDialog<String>(
      context: context,
      builder: (_) => const DeliveryHandoffInputDialog(pickup: true),
    );
    if (otp == null || otp.length != 6) return;
    await _run(
      () => ref
          .read(deliveryRepositoryProvider)
          .startDelivery(order.id, driverId, otp),
    );
  }

  Future<void> _confirmAndCancel(DeliveryOrder order) async {
    final l10n = AppLocalizations.of(context);
    // Goods already with the driver: the server refuses plain cancellation,
    // so the driver files an incident for support instead.
    if (order.status == 'inTrip') {
      final report = await showDeliveryIncidentDialog(context);
      if (report == null) return;
      await _run(() async {
        await ref
            .read(deliveryRepositoryProvider)
            .reportIncident(order.id, report.kind, note: report.note);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.incidentReported)));
        }
      });
      return;
    }
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
      () => ref
          .read(deliveryRepositoryProvider)
          .cancelDelivery(
            order.id,
            reason: 'cancelled_by_driver',
            byDriver: true,
          ),
    );
  }

  Future<void> _confirmAndComplete(DeliveryOrder order, String driverId) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const DeliveryHandoffInputDialog(pickup: false),
    );
    if (code == null || code.length != 6) return;
    final ok = await _run(() async {
      await ref
          .read(deliveryRepositoryProvider)
          .completeDelivery(order.id, driverId, recipientOtp: code);
    });
    if (!ok || !mounted) return;
    // Cash handoff (migration 392), FAIL CLOSED: only a confirmed non-cash
    // delivery pops as done. On a cash delivery — or any doubt about the
    // payment state (the state read failed or came back empty) — the page
    // stays open and the cash card, or a retryable error card, drives what
    // happens next. The captain never leaves a cash delivery without either
    // collecting or consciously backing out of a visible uncollected state.
    CashCollectionState? cash;
    try {
      cash = await ref
          .read(deliveryRepositoryProvider)
          .getCashCollectionState(order.id);
    } catch (_) {
      cash = null;
    }
    if (cash == null || cash.isCash) {
      ref.invalidate(cashCollectionStateProvider(order.id));
      return;
    }
    // Batch 17 #5: confirm the completion with the earnings and return the
    // driver to the hub; previously the page just sat on "completed" and the
    // driver had to back out with no feedback.
    final l10n = AppLocalizations.of(context);
    final fare = order.fare;
    final message = fare == null
        ? l10n.deliveryCompletedSuccess
        : l10n.deliveryCompletedEarnings(
            '${fare.toStringAsFixed(0)} ${order.currency}',
          );
    // Batch 24 #2: pop FIRST, then show the snackbar through the captured
    // messenger (showing before the pop dismissed it with the route), and
    // refresh the hub's providers so the stats row and active-delivery card
    // reflect the completed delivery without a manual pull-to-refresh.
    final messenger = ScaffoldMessenger.of(context);
    ref.invalidate(driverStatsProvider(driverId));
    ref.invalidate(activeDeliveryProvider(driverId));
    ref.invalidate(driverEarningsProvider(driverId));
    context.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmCollection(DeliveryOrder order, String driverId) async {
    final ok = await _run(() async {
      await ref
          .read(deliveryRepositoryProvider)
          .confirmCashCollection(order.id);
    });
    if (!ok || !mounted) return;
    ref.invalidate(cashCollectionStateProvider(order.id));
    ref.invalidate(driverStatsProvider(driverId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).cashCollectedTitle)),
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

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'searching':
        return l10n.searching;
      case 'matched':
        return l10n.matched;
      case 'accepted':
        return l10n.accepted;
      case 'arrived':
        return l10n.arrived;
      case 'picked_up':
        return l10n.pickedUp;
      case 'out_for_delivery':
        return l10n.outForDelivery;
      case 'delivered':
        return l10n.delivered;
      case 'completed':
        return l10n.completed;
      case 'cancelled':
        return l10n.cancelled;
      default:
        return status;
    }
  }

  String _serviceTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'food_delivery':
        return l10n.food;
      case 'grocery_delivery':
        return l10n.grocery;
      case 'marketplace_delivery':
        return l10n.shopping;
      case 'courier':
        return l10n.delivery;
      case 'package_delivery':
        return l10n.package;
      case 'document_delivery':
        return l10n.documents;
      case 'flower_delivery':
        return l10n.flowers;
      case 'retail_delivery':
        return l10n.storefront;
      default:
        return l10n.delivery;
    }
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(appErrorText(context, e))));
      }
    }
  }

  // Stacked label-above-value: the fixed 120px label column squeezed
  // long addresses into narrow fragments at large text scales.
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(value),
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
            error: (e, _) => ErrorState(
              message: appErrorText(context, e),
              retryLabel: AppLocalizations.of(context).errorRetryCta,
              onRetry: () =>
                  ref.invalidate(deliveryOrderByIdProvider(widget.id)),
            ),
            data: (order) {
              if (order == null) {
                return Center(child: Text(l10n.orderNotFound));
              }
              final status = order.status;
              final canCancel = status != 'completed' && status != 'cancelled';
              final customerPhone = _resolveCustomerPhone(order);
              final pickupLatLng = LatLng(
                order.pickupLatitude,
                order.pickupLongitude,
              );
              final dropoffLatLng = LatLng(
                order.dropoffLatitude,
                order.dropoffLongitude,
              );
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
                      webFallbackText: l10n.mapUnavailableOnWebRide,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 1-Tap Navigation Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () {
                            ref
                                .read(mapsServiceProvider)
                                .openNavigation(
                                  GeoLocation(
                                    latitude: order.pickupLatitude,
                                    longitude: order.pickupLongitude,
                                  ),
                                );
                          },
                          icon: const Icon(Icons.storefront_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l10n.navigateToPickup),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            ref
                                .read(mapsServiceProvider)
                                .openNavigation(
                                  GeoLocation(
                                    latitude: order.dropoffLatitude,
                                    longitude: order.dropoffLongitude,
                                  ),
                                );
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(l10n.navigateToCustomer),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (order.riderId != null)
                    UnconfirmedPhoneBanner(customerId: order.riderId!),
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
                          _row(l10n.status, _statusLabel(l10n, status)),
                          _row(
                            l10n.type,
                            _serviceTypeLabel(l10n, order.serviceType),
                          ),
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
                              l10n.amountWithCurrency(
                                order.fare!.toStringAsFixed(0),
                                order.currency == 'EGP'
                                    ? l10n.egp
                                    : order.currency,
                              ),
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
                              l10n.estimatedMinutesValue(
                                order.estimatedMinutes!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Cash handoff: once delivered, the captain collects the
                  // cash here. The card flips to a collected confirmation.
                  // Fail closed: if the collection state cannot be read, a
                  // retryable card keeps the uncollected state visible
                  // instead of silently showing nothing.
                  if (status == 'completed')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CashCollectionSection(
                        state: ref.watch(cashCollectionStateProvider(order.id)),
                        busy: _busy,
                        onCollect: () => _confirmCollection(order, driverId),
                        onDone: () => context.pop(),
                        onRetry: () => ref.invalidate(
                          cashCollectionStateProvider(order.id),
                        ),
                      ),
                    ),
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
                      onPressed: _busy
                          ? null
                          : () => _startWithOtp(driverId, order),
                      child: Text(l10n.startDelivery),
                    ),
                  if (status == 'inTrip')
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _confirmAndComplete(order, driverId),
                      child: Text(l10n.completeDelivery),
                    ),
                  if (canCancel) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _confirmAndCancel(order),
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
