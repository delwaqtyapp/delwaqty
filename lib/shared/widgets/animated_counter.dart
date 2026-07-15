import 'package:flutter/material.dart';
import 'package:delwaqty/core/utils/currency_formatter.dart';

class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 1200),
    this.style,
    this.useCurrency = true,
    this.currencyCode = 'USD',
    this.prefix,
  });

  final double value;
  final Duration duration;
  final TextStyle? style;
  final bool useCurrency;
  final String currencyCode;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final formatted = useCurrency
            ? CurrencyFormatter.format(animatedValue, currencyCode: currencyCode)
            : animatedValue.toStringAsFixed(2);
        final display = prefix != null ? '$prefix$formatted' : formatted;
        return Text(
          display,
          style: style,
        );
      },
    );
  }
}
