import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';
import 'package:delwaqty/features/customer/home_services/domain/entities/car_product.dart';
import 'package:delwaqty/features/customer/home_services/data/repositories/service_booking_repository_impl.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/shimmer_loading.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

final carProductsProvider = FutureProvider<List<CarProduct>>((ref) async {
  final repo = ref.watch(serviceBookingRepositoryProvider);
  return repo.getAvailableCarProducts();
});

class CarMarketplacePage extends ConsumerStatefulWidget {
  const CarMarketplacePage({super.key});

  @override
  ConsumerState<CarMarketplacePage> createState() => _CarMarketplacePageState();
}

class _CarMarketplacePageState extends ConsumerState<CarMarketplacePage> {
  String? selectedCategory;
  final TextEditingController _cityController = TextEditingController();
  String? searchCity;

  static const _categories = <String?>[
    null,
    'car',
    'van',
    'pickup',
    'microbus',
    'tuk_tuk',
  ];

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      searchCity = _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncCars = ref.watch(carProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.carMarketplace),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/home-services/cars/sell'),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text(l10n.sellCarAction),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.carMarketplaceHint,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: l10n.searchRadius.isNotEmpty ? l10n.searchRadius : '',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final label = category == null
                    ? l10n.allCategories
                    : switch (category) {
                        'car' => l10n.carCategoryCar,
                        'van' => l10n.carCategoryVan,
                        'pickup' => l10n.carCategoryPickup,
                        'microbus' => l10n.carCategoryMicrobus,
                        _ => l10n.carCategoryTukTuk,
                      };
                return ChoiceChip(
                  label: Text(label),
                  selected: selectedCategory == category,
                  onSelected: (selected) {
                    setState(() {
                      selectedCategory = selected ? category : null;
                    });
                  },
                );
              },
            ),
          ),
          Expanded(
            child: asyncCars.when(
              loading: () => const Center(child: ShimmerCard(height: 220)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.errorLoading,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(carProductsProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
              data: (allCars) {
                var cars = allCars;
                if (selectedCategory != null) {
                  cars = cars
                      .where((c) => c.category == selectedCategory)
                      .toList();
                }
                if (searchCity != null && searchCity!.isNotEmpty) {
                  cars = cars
                      .where((c) =>
                          c.city.toLowerCase().contains(searchCity!.toLowerCase()))
                      .toList();
                }
                if (cars.isEmpty) {
                  return PremiumEmptyState(
                    icon: Icons.directions_car,
                    title: l10n.noCarsAvailable,
                    message: l10n.carMarketplaceHint,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: cars.length,
                  itemBuilder: (context, index) =>
                      _CarProductCard(car: cars[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CarProductCard extends ConsumerWidget {
  const _CarProductCard({required this.car});

  final CarProduct car;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    Widget photo;
    if (car.photoUrl != null && car.photoUrl!.isNotEmpty) {
      photo = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          car.photoUrl!,
          width: 104,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 104,
            height: 84,
            color: AppColors.surfaceContainerHighestLight,
            child: const Icon(Icons.directions_car, size: 40),
          ),
        ),
      );
    } else {
      photo = Container(
        width: 104,
        height: 84,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighestLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.directions_car,
          size: 40,
          color: AppColors.brandPurple,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('/home-services/cars/${car.id}/order'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              photo,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${car.make ?? ''} ${car.model ?? ''}'
                            '${car.year != null ? ' ${car.year}' : ''}',
                            style: AppTextStyles.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (car.isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successLight.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.carVerified,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.successLight,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _categoryLabel(context, car.category),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.brandSoftGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.event_seat, size: 14),
                        const SizedBox(width: 4),
                        Text('${car.seats}'),
                        const SizedBox(width: 14),
                        const Icon(Icons.location_on, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            car.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${l10n.driverPrice}: '
                          '${car.price.toStringAsFixed(0)} EGP',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.brandPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        FilledButton(
                          onPressed: () => context
                              .push('/home-services/cars/${car.id}/order'),
                          child: Text(l10n.bookTrip),
                        ),
                      ],
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

  String _categoryLabel(BuildContext context, String category) {
    final l10n = AppLocalizations.of(context);
    return switch (category) {
      'van' => l10n.carCategoryVan,
      'pickup' => l10n.carCategoryPickup,
      'microbus' => l10n.carCategoryMicrobus,
      'tuk_tuk' => l10n.carCategoryTukTuk,
      _ => l10n.carCategoryCar,
    };
  }
}