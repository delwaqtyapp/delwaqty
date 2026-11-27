import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/customer/commerce/presentation/providers/cart_providers.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// Guards add-to-cart against silently wiping the cart.
///
/// The cart repository replaces the whole cart when an item from a different
/// merchant is added (single-merchant cart). It used to do that silently, so
/// a customer adding from another store lost their existing order with no
/// warning. Every add-to-cart call site must go through this guard first:
/// it asks the customer to confirm starting a new cart and returns their
/// choice.
Future<bool> confirmCartMerchantSwitch({
  required BuildContext context,
  required WidgetRef ref,
  required String merchantId,
}) async {
  // Await the load so a not-yet-loaded cart can never skip the confirmation.
  final cart =
      ref.read(currentCartProvider) ?? await ref.read(cartProvider.future);
  if (cart == null || cart.merchantId == merchantId || cart.items.isEmpty) {
    return true;
  }
  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l10n.cartConflictTitle),
      content: Text(l10n.cartConflictMessage(cart.merchantName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.cartConflictStartNew),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
