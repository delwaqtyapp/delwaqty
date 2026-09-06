import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/shared/widgets/animated_fade_in.dart';
import 'package:lottie/lottie.dart';

class OrderCompletedPage extends StatefulWidget {
  const OrderCompletedPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderCompletedPage> createState() => _OrderCompletedPageState();
}

class _OrderCompletedPageState extends State<OrderCompletedPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.primaryContainer.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                AnimatedFadeIn(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Lottie.asset(
                      'assets/lottie/order_success.json',
                      width: 150,
                      height: 150,
                      repeat: false,
                      errorBuilder: (_, _, _) => Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                AnimatedFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    l10n.thankYou,
                    style: textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedFadeIn(
                  delay: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      l10n.orderSuccessMessage,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedFadeIn(
                  delay: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${l10n.orderDetails}: #${widget.orderId.substring(widget.orderId.length - 6).toUpperCase()}',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedFadeIn(
                  delay: const Duration(milliseconds: 400),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.estimatedArrival}: 25 ${l10n.minutes}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 500),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              context.push(
                                '/market/orders/${widget.orderId}/tracking',
                              );
                            },
                            child: Text(l10n.trackYourOrder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedFadeIn(
                        delay: const Duration(milliseconds: 600),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              context.go('/home');
                            },
                            child: Text(l10n.backToHome),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
