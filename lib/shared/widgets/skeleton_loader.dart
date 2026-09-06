import 'package:flutter/material.dart';

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = widget.baseColor ??
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final highlight = widget.highlightColor ??
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.2);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [base, highlight, base],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class RestaurantDetailSkeleton extends StatelessWidget {
  const RestaurantDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: double.infinity, height: 240, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    SkeletonBox(width: 120, height: 20),
                    Spacer(),
                    SkeletonBox(width: 60, height: 24, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 12),
                const SkeletonBox(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                const SkeletonBox(width: 200, height: 14),
                const SizedBox(height: 20),
                Row(
                  children: List.generate(
                    4,
                    (_) => const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            SkeletonBox(height: 52, borderRadius: 14),
                            SizedBox(height: 6),
                            SkeletonBox(width: 40, height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SkeletonBox(width: 140, height: 18),
                const SizedBox(height: 12),
                const SkeletonBox(width: double.infinity, height: 60, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RestaurantMenuSkeleton extends StatelessWidget {
  const RestaurantMenuSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SkeletonBox(width: 72, height: 72, borderRadius: 10),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160, height: 16),
                  SizedBox(height: 6),
                  SkeletonBox(width: 100, height: 12),
                  SizedBox(height: 6),
                  SkeletonBox(width: 80, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantReviewsSkeleton extends StatelessWidget {
  const RestaurantReviewsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonCircle(size: 36),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 100, height: 14),
                    SizedBox(height: 4),
                    SkeletonBox(width: 60, height: 12),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 14),
            SizedBox(height: 4),
            SkeletonBox(width: 200, height: 14),
          ],
        ),
      ),
    );
  }
}
