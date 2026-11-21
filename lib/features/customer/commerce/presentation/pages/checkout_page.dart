import 'package:delwaqty/features/customer/commerce/presentation/providers/cart_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart'
    as commerce;
import 'package:delwaqty/features/customer/commerce/domain/entities/coupon.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/customer/location/presentation/widgets/smart_map_picker_sheet.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/core/errors/app_error_text.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String _paymentMethod = 'cash';
  UserLocation? _deliveryLocation;
  final _addressController = TextEditingController();
  final _couponController = TextEditingController();
  bool _isPlacing = false;
  bool _addressPrefilled = false;

  @override
  void initState() {
    super.initState();
    // A snackbar queued on an earlier page (e.g. add-to-cart) must never
    // overlay Place Order; drop it as checkout opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
    final loc = ref.read(userLocationProvider).value;
    if (loc != null && loc.detailedAddress.isNotEmpty) {
      _addressController.text = loc.detailedAddress;
      _deliveryLocation = loc;
      _addressPrefilled = true;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _pickAddressOnMap() async {
    final picked = await SmartMapPickerSheet.show(context);
    if (picked != null && mounted) {
      setState(() {
        _addressController.text = picked.detailedAddress;
        _deliveryLocation = picked;
        _addressPrefilled = true;
      });
    }
  }

  Future<void> _addNewAddress() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _addressController.text);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(l10n.addNewAddress),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText: l10n.selectDeliveryAddress,
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(l10n.saveChanges),
            ),
          ],
        ),
      );
      if (result == null || result.isEmpty || !mounted) return;
      setState(() {
        if (result != _addressController.text) _deliveryLocation = null;
        _addressController.text = result;
      });
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final cartAsync = ref.watch(_cartFutureProvider);
    final userLoc = ref.watch(userLocationProvider).value;
    final savedAddresses = ref.watch(_savedAddressesProvider).value;
    if (!_addressPrefilled &&
        _addressController.text.isEmpty &&
        savedAddresses != null &&
        savedAddresses.isNotEmpty) {
      final def = savedAddresses.firstWhere(
        (a) => a['is_default'] == true,
        orElse: () => savedAddresses.first,
      );
      final lat = (def['latitude'] as num?)?.toDouble();
      final lng = (def['longitude'] as num?)?.toDouble();
      final addr = (def['address'] as String?) ?? '';
      if (lat != null && lng != null && addr.isNotEmpty) {
        _addressController.text = addr;
        _deliveryLocation = UserLocation(
          latitude: lat,
          longitude: lng,
          detailedAddress: addr,
        );
        _addressPrefilled = true;
      }
    }
    if (!_addressPrefilled &&
        _addressController.text.isEmpty &&
        userLoc != null &&
        userLoc.detailedAddress.isNotEmpty) {
      _addressController.text = userLoc.detailedAddress;
      _deliveryLocation = userLoc;
      _addressPrefilled = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkout)),
      body: cartAsync.when(
        data: (cart) {
          if (cart == null || cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.emptyCart, style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => context.push('/market'),
                    child: Text(l10n.browseMerchants),
                  ),
                ],
              ),
            );
          }

          final deliveryFee =
              ref.watch(_merchantFeeProvider(cart.merchantId)).value ??
              cart.deliveryFee;
          final orderTotal = cart.subtotal + deliveryFee - cart.discount;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimatedFadeIn(child: _SectionTitle(title: l10n.deliveryAddress)),
              const SizedBox(height: 8),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 100),
                child: TextField(
                  controller: _addressController,
                  onChanged: (_) => _deliveryLocation = null,
                  decoration: InputDecoration(
                    hintText: l10n.selectDeliveryAddress,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: IconButton(
                      tooltip: l10n.pickLocationOnMap,
                      icon: const Icon(Icons.map_rounded),
                      onPressed: _pickAddressOnMap,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              if (savedAddresses != null && savedAddresses.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: savedAddresses.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final a = savedAddresses[i];
                      final lat = (a['latitude'] as num?)?.toDouble();
                      final lng = (a['longitude'] as num?)?.toDouble();
                      final label =
                          (a['label'] as String?)?.trim().isNotEmpty == true
                          ? a['label'] as String
                          : (a['address'] as String? ?? '');
                      final selected =
                          lat != null &&
                          _deliveryLocation?.latitude == lat &&
                          _deliveryLocation?.longitude == lng;
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: lat == null || lng == null
                            ? null
                            : (_) => setState(() {
                                final addr = (a['address'] as String?) ?? '';
                                _addressController.text = addr;
                                _deliveryLocation = UserLocation(
                                  latitude: lat,
                                  longitude: lng,
                                  detailedAddress: addr,
                                );
                                _addressPrefilled = true;
                              }),
                      );
                    },
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _pickAddressOnMap,
                    icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                    label: Text(l10n.pickLocationOnMap),
                  ),
                  TextButton(
                    onPressed: _addNewAddress,
                    child: Text(l10n.addNewAddress),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 200),
                child: _SectionTitle(title: l10n.paymentMethod),
              ),
              const SizedBox(height: 8),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 300),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'cash',
                      label: Text(l10n.cashOnDelivery),
                      icon: const Icon(Icons.payments_outlined),
                    ),
                    ButtonSegment(
                      value: 'instapay',
                      label: Text(l10n.paymentInstapay),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                    ),
                    ButtonSegment(
                      value: 'vodafone_cash',
                      label: Text(l10n.paymentVodafoneCash),
                      icon: const Icon(Icons.phone_iphone_rounded),
                    ),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (v) =>
                      setState(() => _paymentMethod = v.first),
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 400),
                child: _SectionTitle(title: l10n.couponCode),
              ),
              const SizedBox(height: 8),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 500),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _couponController,
                        decoration: InputDecoration(
                          hintText: l10n.enterCouponCode,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: () async {
                        final code = _couponController.text.trim();
                        if (code.isEmpty) return;
                        try {
                          final repo = ref.read(couponRepositoryProvider);
                          final coupon = await repo.validateCoupon(
                            code,
                            cart.subtotal,
                          );
                          if (!mounted) return;
                          if (coupon != null) {
                            double discount = 0;
                            switch (coupon.type) {
                              case CouponType.percentage:
                                discount = cart.subtotal * (coupon.value / 100);
                                if (coupon.maximumDiscount != null &&
                                    discount > coupon.maximumDiscount!) {
                                  discount = coupon.maximumDiscount!;
                                }
                                break;
                              case CouponType.fixed:
                                discount = coupon.value;
                                break;
                              case CouponType.freeDelivery:
                                discount = deliveryFee;
                                break;
                            }
                            final maxDiscount = cart.subtotal + deliveryFee;
                            discount = discount.clamp(0.0, maxDiscount);
                            await ref
                                .read(cartProvider.notifier)
                                .applyCoupon(coupon.code, discount: discount);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${l10n.couponApplied} -${discount.toStringAsFixed(0)} ${l10n.egp}',
                                  ),
                                  backgroundColor: colorScheme.primary,
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.couponInvalid),
                                  backgroundColor: colorScheme.error,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(appErrorText(context, e)),
                                backgroundColor: colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(l10n.apply),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 600),
                child: _SectionTitle(title: l10n.orderSummary),
              ),
              const SizedBox(height: 8),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 700),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: l10n.subtotal,
                          value:
                              '${cart.subtotal.toStringAsFixed(0)} ${l10n.egp}',
                        ),
                        if (deliveryFee > 0)
                          _SummaryRow(
                            label: l10n.deliveryFee,
                            value:
                                '${deliveryFee.toStringAsFixed(0)} ${l10n.egp}',
                          ),
                        if (cart.discount > 0)
                          _SummaryRow(
                            label: l10n.discount,
                            value:
                                '-${cart.discount.toStringAsFixed(0)} ${l10n.egp}',
                            color: colorScheme.primary,
                          ),
                        Divider(color: colorScheme.outlineVariant),
                        _SummaryRow(
                          label: l10n.total,
                          value: '${orderTotal.toStringAsFixed(0)} ${l10n.egp}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AnimatedFadeIn(
                delay: const Duration(milliseconds: 800),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isPlacing ? null : () => _placeOrder(cart),
                    child: _isPlacing
                        ? AppLoader.circular(
                            size: 20,
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          )
                        : Text(l10n.placeOrder),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: AppLoader.circular()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(l10n.error, style: textTheme.titleMedium),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(cartProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder(commerce.Cart cart) async {
    final l10n = AppLocalizations.of(context);
    final cs = context.colorScheme;
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.addressRequired),
          backgroundColor: cs.error,
        ),
      );
      return;
    }
    if (_deliveryLocation == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.pickLocationOnMap)));
      return;
    }
    setState(() => _isPlacing = true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);

      final order = await orderRepo.createOrder(
        merchantId: cart.merchantId,
        merchantName: cart.merchantName,
        items: cart.items,
        subtotal: cart.subtotal,
        deliveryFee: cart.deliveryFee,
        discount: cart.discount,
        total: cart.total,
        deliveryAddress: address,
        deliveryLatitude: _deliveryLocation!.latitude,
        deliveryLongitude: _deliveryLocation!.longitude,
        paymentMethod: _paymentMethod,
        couponCode: cart.couponCode,
        idempotencyKey: 'checkout-${cart.id}',
      );

      await ref.read(cartProvider.notifier).clear();

      if (!mounted) return;
      context.go('/market/order-completed/${order.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.somethingWentWrong),
          backgroundColor: cs.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPlacing = false);
      }
    }
  }
}

final _cartFutureProvider = Provider<AsyncValue<commerce.Cart?>>((ref) {
  return ref.watch(cartProvider);
});

/// Saved delivery addresses (user_addresses) for the checkout picker.
final _savedAddressesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const <Map<String, dynamic>>[];
  final rows = await client
      .from('user_addresses')
      .select('id,label,address,latitude,longitude,is_default')
      .eq('user_id', uid)
      .order('is_default', ascending: false)
      .order('created_at');
  return (rows as List<dynamic>).cast<Map<String, dynamic>>();
});

/// The local cart never stores the merchant's delivery fee, so the summary
/// must read it from the merchant row (the server charges the same value).
final _merchantFeeProvider = FutureProvider.family<double, String>((
  ref,
  merchantId,
) async {
  if (merchantId.isEmpty) return 0;
  final row = await Supabase.instance.client
      .from('merchants')
      .select('delivery_fee')
      .eq('id', merchantId)
      .maybeSingle();
  return (row?['delivery_fee'] as num?)?.toDouble() ?? 0;
});

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
