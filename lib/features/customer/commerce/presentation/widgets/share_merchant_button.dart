import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:delwaqty/features/customer/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The text shared for a merchant: name, then the address when known.
String composeMerchantShareText({
  required String merchantName,
  required String appName,
  String? address,
}) {
  final buffer = StringBuffer('$merchantName - $appName');
  if (address != null && address.trim().isNotEmpty) {
    buffer.write('\n$address');
  }
  return buffer.toString();
}

/// App-bar share action for a merchant/restaurant page. Shares the merchant
/// name and address through the platform share sheet.
class ShareMerchantButton extends StatelessWidget {
  const ShareMerchantButton({super.key, required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      tooltip: l10n.share,
      icon: const Icon(Icons.share_outlined),
      onPressed: () {
        final address = [
          if (merchant.address != null && merchant.address!.isNotEmpty)
            merchant.address!,
          if (merchant.city != null && merchant.city!.isNotEmpty)
            merchant.city!,
        ].join(', ');
        Share.share(
          composeMerchantShareText(
            merchantName: merchant.name,
            appName: l10n.appName,
            address: address.isEmpty ? null : address,
          ),
        );
      },
    );
  }
}
