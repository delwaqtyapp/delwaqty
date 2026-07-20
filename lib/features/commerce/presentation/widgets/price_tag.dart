import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class PriceTag extends StatelessWidget {
  const PriceTag({
    required this.price,
    this.originalPrice,
    this.size = 'medium',
    super.key,
  });

  final double price;
  final double? originalPrice;
  final String size;

  TextStyle _priceStyle(BuildContext context) {
    final base = size == 'small'
        ? Theme.of(context).textTheme.bodySmall
        : size == 'large'
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.titleMedium;
    return (base ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = originalPrice != null && originalPrice! > price;
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${price.toStringAsFixed(0)} ${l10n.currencySymbol}',
          style: _priceStyle(context),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: 6),
          Text(
            '${originalPrice!.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: size == 'small' ? 10 : 12,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
            ),
          ),
        ],
      ],
    );
  }
}
