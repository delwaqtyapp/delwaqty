import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/restaurant/restaurant_module.dart';
import 'package:delwaqty/features/restaurant/domain/entities/offer.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';

final _offersProvider = FutureProvider.family<List<Offer>, String>((ref, merchantId) async {
  final repo = ref.watch(offerRepositoryProvider);
  return repo.getActiveOffers(merchantId);
});

class RestaurantOffersPage extends ConsumerWidget {
  const RestaurantOffersPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final offersAsync = ref.watch(_offersProvider(merchantId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activeOffers)),
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.local_offer_outlined,
                title: l10n.noOffersAvailable,
                message: l10n.nearbyEmptyHint,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_offersProvider(merchantId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                return AnimatedFadeIn(
                  delay: Duration(milliseconds: index * 80),
                  child: _OfferCard(offer: offer),
                );
              },
            ),
          );
        },
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ShimmerCard(height: 120),
          ),
        ),
        error: (_, __) => Center(
          child: ErrorState(message: l10n.errorLoading),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final isPercentage = offer.discountType == 'percentage';
    final discountText = isPercentage
        ? '${offer.discountValue.toStringAsFixed(0)}% OFF'
        : '${offer.discountValue.toStringAsFixed(0)} ${l10n.sar} OFF';

    final isExpired = offer.expiresAt != null && offer.expiresAt!.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isExpired
                ? theme.colorScheme.outline.withOpacity(0.2)
                : theme.colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isExpired
                      ? [Colors.grey.shade300, Colors.grey.shade200]
                      : [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer_rounded,
                    color: Colors.white.withOpacity(0.9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    discountText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isExpired) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.offerExpired,
                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (offer.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      offer.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (offer.minimumOrder != null && offer.minimumOrder! > 0) ...[
                        Icon(Icons.shopping_cart_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          l10n.minOrderRequired(offer.minimumOrder!.toStringAsFixed(0), l10n.sar),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (offer.expiresAt != null) ...[
                        Icon(Icons.schedule_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          l10n.validUntil(_formatDate(offer.expiresAt!)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
