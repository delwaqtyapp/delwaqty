import 'package:delwaqty/features/customer/commerce/presentation/providers/cart_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/features/customer/commerce/commerce_module.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/cart.dart'
    as commerce;
import 'package:delwaqty/features/customer/commerce/domain/entities/coupon.dart';
import 'package:delwaqty/features/customer/location/presentation/providers/location_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
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
    // Batch 20 #2: this used to just edit the current checkout address text.
    // Now it is a real add-address form: label + address + exact location,
    // saved to user_addresses and selected for this checkout.
    final l10n = AppLocalizations.of(context);
    final labelController = TextEditingController();
    final addressController = TextEditingController();
    // Batch 23 #2: do NOT prefill the address with the reverse-geocoded
    // name - the user types their own address text; the geocoded string is
    // the fallback only when they leave the field empty.
    UserLocation? loc = _deliveryLocation;
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setLocal) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(l10n.addNewAddress),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(
                    hintText: l10n.addressLabel,
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: l10n.selectDeliveryAddress,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
                  label: Text(l10n.pickLocationOnMap),
                  onPressed: () async {
                    final picked = await SmartMapPickerSheet.show(context);
                    if (picked != null) {
                      setLocal(() {
                        loc = picked;
                        addressController.text = picked.detailedAddress;
                      });
                    }
                  },
                ),
                if (loc == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.addressLocationRequired,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: loc == null
                    ? null
                    : () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      );
      if (saved != true || !mounted || loc == null) return;
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;
      final addressText = addressController.text.trim().isNotEmpty
          ? addressController.text.trim()
          : loc!.detailedAddress;
      await client.from('user_addresses').insert({
        'user_id': uid,
        'label': labelController.text.trim(),
        'address': addressText,
        'latitude': loc!.latitude,
        'longitude': loc!.longitude,
        'is_default': false,
      });
      if (!mounted) return;
      ref.invalidate(_savedAddressesProvider);
      final labelText = labelController.text.trim();
      setState(() {
        _addressController.text = labelText.isNotEmpty
            ? '$labelText - $addressText'
            : addressText;
        _deliveryLocation = loc;
        _addressPrefilled = true;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.addressSaved)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.locationConfirmFailed)));
      }
    } finally {
      labelController.dispose();
      addressController.dispose();
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
      final lbl = (def['label'] as String?)?.trim() ?? '';
      if (lat != null && lng != null && addr.isNotEmpty) {
        _addressController.text = lbl.isNotEmpty ? '$lbl - $addr' : addr;
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
          // Migration 395: the delay-apology gift shows here as an
          // automatic platform-credit discount. The server is authoritative
          // at create_order; the provider mirrors min(available, amount due)
          // for display only.
          final dueBeforeCredit = cart.subtotal + deliveryFee - cart.discount;
          final platformCredit =
              ref.watch(_platformCreditProvider(dueBeforeCredit)).value ?? 0.0;
          final creditApplied = dueBeforeCredit <= 0
              ? 0.0
              : platformCredit.clamp(0.0, dueBeforeCredit).toDouble();
          final orderTotal = dueBeforeCredit - creditApplied;

          // 395: pull to refresh re-reads the gift balance (and the fee),
          // so credit granted or spent elsewhere never stays stale here.
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_platformCreditProvider);
              ref.invalidate(_merchantFeeProvider(cart.merchantId));
              // Keep the spinner up until the fresh reads actually come
              // back; a failure surfaces through the provider error state.
              try {
                await ref.read(_platformCreditProvider(dueBeforeCredit).future);
                await ref.read(_merchantFeeProvider(cart.merchantId).future);
              } catch (_) {}
            },
            child: ListView(
              // Always scrollable so pull-to-refresh works even when the
              // checkout content fits on screen.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                AnimatedFadeIn(
                  child: _SectionTitle(title: l10n.deliveryAddress),
                ),
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
                  SavedAddressChipStrip(
                    addresses: savedAddresses,
                    isSelected: (a) {
                      final lat = (a['latitude'] as num?)?.toDouble();
                      final lng = (a['longitude'] as num?)?.toDouble();
                      return lat != null &&
                          _deliveryLocation?.latitude == lat &&
                          _deliveryLocation?.longitude == lng;
                    },
                    onSelect: (a) => setState(() {
                      final lat = (a['latitude'] as num?)?.toDouble();
                      final lng = (a['longitude'] as num?)?.toDouble();
                      final addr = (a['address'] as String?) ?? '';
                      final lbl = (a['label'] as String?)?.trim() ?? '';
                      _addressController.text = lbl.isNotEmpty
                          ? '$lbl - $addr'
                          : addr;
                      _deliveryLocation = UserLocation(
                        latitude: lat!,
                        longitude: lng!,
                        detailedAddress: addr,
                      );
                      _addressPrefilled = true;
                    }),
                  ),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _pickAddressOnMap,
                      icon: const Icon(
                        Icons.edit_location_alt_rounded,
                        size: 18,
                      ),
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
                  // Full-width option tiles: a horizontal segmented control
                  // fragments the Arabic labels at large text scales.
                  child: Column(
                    children: [
                      _PaymentOptionTile(
                        value: 'cash',
                        label: l10n.cashOnDelivery,
                        icon: Icons.payments_outlined,
                        selected: _paymentMethod == 'cash',
                        onSelected: (v) => setState(() => _paymentMethod = v),
                      ),
                      const SizedBox(height: 8),
                      _PaymentOptionTile(
                        value: 'instapay',
                        label: l10n.paymentInstapay,
                        icon: Icons.account_balance_wallet_outlined,
                        selected: _paymentMethod == 'instapay',
                        onSelected: (v) => setState(() => _paymentMethod = v),
                      ),
                      const SizedBox(height: 8),
                      _PaymentOptionTile(
                        value: 'vodafone_cash',
                        label: l10n.paymentVodafoneCash,
                        icon: Icons.phone_iphone_rounded,
                        selected: _paymentMethod == 'vodafone_cash',
                        onSelected: (v) => setState(() => _paymentMethod = v),
                      ),
                    ],
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
                                  discount =
                                      cart.subtotal * (coupon.value / 100);
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
                if (platformCredit > 0) ...[
                  const SizedBox(height: 16),
                  AnimatedFadeIn(
                    delay: const Duration(milliseconds: 550),
                    child: Card(
                      elevation: 0,
                      color: colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.card_giftcard_rounded,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.platformCreditAutoApplied(
                                  creditApplied.toStringAsFixed(0),
                                ),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
                          if (creditApplied > 0)
                            _SummaryRow(
                              label: l10n.platformCredit,
                              value:
                                  '-${creditApplied.toStringAsFixed(0)} ${l10n.egp}',
                              color: colorScheme.primary,
                            ),
                          Divider(color: colorScheme.outlineVariant),
                          _SummaryRow(
                            label: l10n.total,
                            value:
                                '${orderTotal.toStringAsFixed(0)} ${l10n.egp}',
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
            ),
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
      // The gift was spent server-side; drop the cached balance.
      ref.invalidate(_platformCreditProvider);
      context.go('/market/order-completed/${order.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(checkoutErrorText(context, e)),
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

/// Spendable platform credit (migration 395): the delay-apology gift the
/// server auto-applies as a discount inside create_order. Display-only
/// mirror; a missing pre-395 backend must not break checkout. autoDispose
/// keeps no stale balance after leaving checkout, ref.watch(authStateProvider)
/// re-fetches when the signed-in user changes, and the family key is the
/// amount due, so the server-side min(balance, due) is what renders.
final _platformCreditProvider = FutureProvider.autoDispose
    .family<double, double>((ref, amountDue) async {
      final auth = ref.watch(authStateProvider);
      if (auth is! AuthAuthenticated) return 0;
      final client = Supabase.instance.client;
      try {
        final res = await client.rpc(
          'my_platform_credit',
          params: {'p_amount_due': amountDue},
        );
        final map = Map<String, dynamic>.from(res as Map);
        if (map['ok'] != true) return 0;
        return (map['applies'] as num?)?.toDouble() ?? 0;
      } catch (_) {
        return 0;
      }
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

/// Full-width radio-style payment option used instead of a horizontal
/// segmented control so long Arabic labels never fragment.
class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => onSelected(value),
          borderRadius: BorderRadius.circular(12),
          canRequestFocus: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of saved-address chips shown on the checkout page.
/// Public so widget tests can render the strip in isolation at extreme text
/// scales: its height grows with the text scale (clamped at 1.6x) so
/// large-text chips are never clipped.
class SavedAddressChipStrip extends StatelessWidget {
  const SavedAddressChipStrip({
    super.key,
    required this.addresses,
    required this.isSelected,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> addresses;
  final bool Function(Map<String, dynamic> address) isSelected;

  /// Called only for addresses that carry coordinates.
  final void Function(Map<String, dynamic> address) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          44 *
          MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6).toDouble(),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 8),
        itemCount: addresses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = addresses[i];
          final lat = (a['latitude'] as num?)?.toDouble();
          final lng = (a['longitude'] as num?)?.toDouble();
          final label = (a['label'] as String?)?.trim().isNotEmpty == true
              ? a['label'] as String
              : (a['address'] as String? ?? '');
          return ChoiceChip(
            label: Text(label),
            selected: isSelected(a),
            onSelected: lat == null || lng == null ? null : (_) => onSelect(a),
          );
        },
      ),
    );
  }
}
