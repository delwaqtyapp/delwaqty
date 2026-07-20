import 'dart:async';

import 'package:flutter/material.dart';

import 'package:delwaqty/features/driver/domain/entities/ride_offer.dart';
import 'package:delwaqty/features/ride/presentation/widgets/ride_type_info.dart';
import 'package:delwaqty/l10n/app_localizations.dart';

class RideOfferSheet extends StatefulWidget {
  const RideOfferSheet({required this.offer, super.key});

  final RideOffer offer;

  @override
  State<RideOfferSheet> createState() => _RideOfferSheetState();
}

class _RideOfferSheetState extends State<RideOfferSheet> {
  late Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _seconds = widget.offer.remaining.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = widget.offer.remaining.inSeconds;
      setState(() => _seconds = remaining);
      if (remaining <= 0) {
        _timer.cancel();
        Navigator.of(context).maybePop(null);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final offer = widget.offer;
    final info = RideTypeInfo.of(offer.rideType, l10n);
    final total = widget.offer.remaining.inSeconds.clamp(0, 20);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.incomingRequest,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer,
                  ),
                  child: Text('$_seconds',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: total / 20),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(info.icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(info.name, style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  l10n.amountWithCurrency(
                      offer.fare.toStringAsFixed(0), l10n.currencySymbol),
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.estimatedEarnings,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _AddressRow(
              icon: Icons.my_location_rounded,
              color: Colors.green,
              label: l10n.pickup,
              address: offer.pickupAddress,
              trailing:
                  '${offer.pickupDistanceKm.toStringAsFixed(1)} km ${l10n.away}',
            ),
            const SizedBox(height: 12),
            _AddressRow(
              icon: Icons.location_on_rounded,
              color: Colors.red,
              label: l10n.destination,
              address: offer.dropoffAddress,
              trailing: '${offer.distanceKm.toStringAsFixed(1)} km',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(l10n.reject),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(l10n.accept),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
    required this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String address;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              Text(address.isEmpty ? '-' : address,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(trailing,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
