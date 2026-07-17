import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/extensions/context_extensions.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, l10n)),
            SliverToBoxAdapter(child: _buildSearchBar(context, l10n)),
            SliverToBoxAdapter(child: _buildServiceGrid(context, l10n)),
            SliverToBoxAdapter(child: _buildSectionTitle(context, l10n.nearby, l10n)),
            SliverToBoxAdapter(child: _buildNearbyList(context)),
            SliverToBoxAdapter(child: _buildPromoBanner(context, l10n)),
            SliverToBoxAdapter(child: _buildSectionTitle(context, l10n.popular, l10n)),
            SliverToBoxAdapter(child: _buildPopularList(context)),
            SliverToBoxAdapter(child: _buildSectionTitle(context, l10n.recommended, l10n)),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildRecommendedItem(context, index),
                childCount: 5,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colorScheme.primary,
                    context.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: context.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  l10n.appNameAr,
                  style: TextStyle(
                    color: context.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Riyadh, Saudi Arabia',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l10n.hello,
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _buildNotificationBadge(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBadge(BuildContext context) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: IconButton(
        onPressed: () => context.push('/notifications'),
        icon: Badge(
          backgroundColor: context.colorScheme.error,
          smallSize: 8,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: context.colorScheme.onSurface,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: GestureDetector(
          onTap: () => context.push('/market/search'),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.searchHint,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.tune_rounded,
                  color: context.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context, AppLocalizations l10n) {
    final services = [
      _ServiceData(Icons.restaurant_rounded, l10n.restaurants, const Color(0xFFE65100)),
      _ServiceData(Icons.local_grocery_store_rounded, l10n.grocery, const Color(0xFF2E7D32)),
      _ServiceData(Icons.local_pharmacy_rounded, l10n.pharmacy, const Color(0xFF0277BD)),
      _ServiceData(Icons.local_taxi_rounded, l10n.ride, const Color(0xFF512DA8)),
      _ServiceData(Icons.home_repair_service_rounded, l10n.homeServices, const Color(0xFF4E342E)),
      _ServiceData(Icons.local_shipping_rounded, l10n.delivery, const Color(0xFF00897B)),
      _ServiceData(Icons.local_offer_rounded, l10n.offers, const Color(0xFFAD1457)),
      _ServiceData(Icons.more_horiz_rounded, l10n.settings, const Color(0xFF616161)),
    ];

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 8,
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index];
            return _ServiceTile(
              icon: service.icon,
              label: service.label,
              color: service.color,
              delay: Duration(milliseconds: 250 + index * 50),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(l10n.viewAll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyList(BuildContext context) {
    final items = [
      _NearbyData('Pizza Palace', '4.5', '1.2 km', '🍕'),
      _NearbyData('Fresh Market', '4.8', '0.8 km', '🛒'),
      _NearbyData('Quick Pharmacy', '4.2', '2.1 km', '💊'),
      _NearbyData('CleanPro', '4.6', '1.5 km', '🧹'),
      _NearbyData('SpeedBite', '4.9', '0.5 km', '🍔'),
    ];

    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 400),
      child: SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            return _NearbyCard(data: item, onTap: () => context.push('/market'));
          },
        ),
      ),
    );
  }

  Widget _buildPromoBanner(BuildContext context, AppLocalizations l10n) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 450),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6750A4), Color(0xFF9A82DB)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6750A4).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '30% OFF',
                      style: context.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.onboardingDesc2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'DELWAQTY30',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopularList(BuildContext context) {
    return AnimatedFadeIn(
      delay: const Duration(milliseconds: 500),
      child: SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return _PopularCard(index: index, onTap: () => context.push('/market'));
          },
        ),
      ),
    );
  }

  Widget _buildRecommendedItem(BuildContext context, int index) {
    final names = ['Burger King', 'Super Mart', 'Health Pharmacy', 'FixIt Pro', 'Express'];
    final types = ['Restaurant', 'Grocery', 'Pharmacy', 'Services', 'Delivery'];
    final emojis = ['🍔', '🛒', '💊', '🔧', '📦'];
    final colors = [
      const Color(0xFFE65100),
      const Color(0xFF2E7D32),
      const Color(0xFF0277BD),
      const Color(0xFF512DA8),
      const Color(0xFF00897B),
    ];

    return AnimatedFadeIn(
      delay: Duration(milliseconds: 550 + index * 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: GestureDetector(
          onTap: () => context.push('/market'),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors[index].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[index],
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        types[index],
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: context.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceData {
  const _ServiceData(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;
}

class _NearbyData {
  const _NearbyData(this.name, this.rating, this.distance, this.emoji);
  final String name;
  final String rating;
  final String distance;
  final String emoji;
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.delay,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedFadeIn(
      delay: delay,
      child: GestureDetector(
        onTap: () {},
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.12),
                    color.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.data, required this.onTap});

  final _NearbyData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    context.colorScheme.primaryContainer.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Text(data.emoji, style: const TextStyle(fontSize: 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Colors.amber[600]),
                      const SizedBox(width: 2),
                      Text(data.rating, style: context.textTheme.bodySmall),
                      const Spacer(),
                      Text(
                        data.distance,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
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

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.index, required this.onTap});

  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final names = ['Pizza Palace', 'Fresh Market', 'Quick Pharmacy', 'CleanPro', 'SpeedBite'];
    final emojis = ['🍕', '🛒', '💊', '🧹', '🍔'];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    context.colorScheme.primaryContainer.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Center(
                child: Text(emojis[index], style: const TextStyle(fontSize: 36)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    names[index],
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Open Now',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
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
