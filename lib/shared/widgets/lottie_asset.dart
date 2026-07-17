import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieAsset extends StatelessWidget {
  const LottieAsset({
    required this.assetPath,
    super.key,
    this.width,
    this.height,
    this.repeat = true,
    this.reverse = false,
    this.animate = true,
    this.onLoaded,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final bool repeat;
  final bool reverse;
  final bool animate;
  final void Function(LottieComposition)? onLoaded;

  static const orderSuccess = 'assets/lottie/order_success.json';
  static const emptyCart = 'assets/lottie/empty_cart.json';
  static const emptyFavorites = 'assets/lottie/empty_favorites.json';
  static const loading = 'assets/lottie/loading.json';
  static const noConnection = 'assets/lottie/no_connection.json';
  static const searchEmpty = 'assets/lottie/search_empty.json';

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      assetPath,
      width: width,
      height: height,
      repeat: repeat,
      reverse: reverse,
      animate: animate,
      onLoaded: onLoaded,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width ?? 120,
          height: height ?? 120,
          child: Icon(
            Icons.animation_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        );
      },
    );
  }
}
