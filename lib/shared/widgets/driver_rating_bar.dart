import 'package:flutter/material.dart';

import 'package:delwaqty/core/theme/app_colors.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

/// The platform's stars+comment driver rating control: five stars, a
/// written comment field and a submit button. Used by the direct-delivery
/// tracking page and the commerce order tracking page (migration 392), so
/// the customer always sees the same rating UI for the delivery driver.
class DriverRatingBar extends StatelessWidget {
  const DriverRatingBar({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    required this.controller,
    required this.onSubmit,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  tooltip: l10n.rateDriver,
                  icon: Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: star <= rating ? AppColors.rating : null,
                    size: 36,
                  ),
                  onPressed: () => onRatingChanged(star),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: l10n.trackingUpdatesHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: rating > 0 ? onSubmit : null,
                child: Text(l10n.submit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
