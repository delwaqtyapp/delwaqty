import 'package:flutter/material.dart';
import 'package:delwaqty/features/commerce/domain/entities/product.dart';
import 'package:delwaqty/features/commerce/domain/entities/favorite.dart';
import 'package:delwaqty/features/commerce/presentation/widgets/favorite_button.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, required this.onTap, super.key});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount =
        product.originalPrice != null && product.originalPrice! > product.price;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${((1 - product.price / product.originalPrice!) * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (!product.isAvailable)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).unavailable,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: FavoriteButton(
                        targetId: product.id,
                        type: FavoriteType.product,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${product.price.toStringAsFixed(0)} ${AppLocalizations.of(context).currencySymbol}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${product.originalPrice!.toStringAsFixed(0)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
