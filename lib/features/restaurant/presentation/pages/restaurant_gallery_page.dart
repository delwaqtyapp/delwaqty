import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/commerce/commerce_module.dart';
import 'package:delwaqty/features/commerce/domain/entities/merchant.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:delwaqty/shared/widgets/premium_empty_state.dart';
import 'package:delwaqty/shared/widgets/error_state.dart';
import 'package:delwaqty/shared/widgets/app_loader.dart';
import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/core/theme/app_text_styles.dart';

final _merchantProvider = FutureProvider.family<Merchant?, String>((ref, id) async {
  final repo = ref.watch(merchantRepositoryProvider);
  return repo.getMerchantById(id);
});

class RestaurantGalleryPage extends ConsumerWidget {
  const RestaurantGalleryPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final merchantAsync = ref.watch(_merchantProvider(merchantId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gallery)),
      body: merchantAsync.when(
        data: (merchant) {
          if (merchant == null) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.photo_library_outlined,
                title: l10n.noData,
                message: l10n.errorLoading,
              ),
            );
          }

          final images = <String>[];
          if (merchant.imageUrl != null) images.add(merchant.imageUrl!);

          if (images.isEmpty) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.photo_library_outlined,
                title: l10n.gallery,
                message: l10n.noGalleryImages,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_merchantProvider(merchantId)),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return AnimatedFadeIn(
                  delay: Duration(milliseconds: 60 * index),
                  child: GestureDetector(
                    onTap: () => _openFullScreen(context, images, index),
                    child: Hero(
                      tag: 'gallery-$merchantId-$index',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: AppLoaderCircular()),
        error: (e, _) => Center(
          child: ErrorState(
            message: l10n.errorLoading,
            onRetry: () => ref.invalidate(_merchantProvider(merchantId)),
            retryLabel: l10n.retry,
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, List<String> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(images: images, initialIndex: initialIndex),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  const _FullScreenGallery({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.onSurface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.onSurface,
        foregroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: AppTextStyles.titleMedium.copyWith(color: Theme.of(context).colorScheme.surface),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: 'gallery-gallery-$index',
                child: Image.network(
                  widget.images[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                    size: 64,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
