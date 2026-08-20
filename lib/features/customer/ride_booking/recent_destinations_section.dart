import 'package:flutter/material.dart';
import 'package:delwaqty/l10n/app_localizations.dart';
import 'package:delwaqty/features/customer/ride_booking/ride_booking_theme.dart';
import 'package:delwaqty/features/customer/ride_booking/ride_booking_theme.dart' as rb;

class RecentDestinationsSection extends StatelessWidget {
  const RecentDestinationsSection({
    required this.recents,
    super.key,
  });

  final List<RecentDest> recents;

  @override
  Widget build(BuildContext context) {
    if (recents.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: rb.RideBookingTheme.screenPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recentSearches,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: RideBookingTheme.whiteAlpha80,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final dest = recents[index];
              return _RecentCard(dest: dest);
            },
          ),
        ),
      ],
    );
  }
}

class RecentDest {
  const RecentDest({
    required this.name,
    required this.address,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String address;
  final IconData icon;
  final VoidCallback onTap;
}

class _RecentCard extends StatefulWidget {
  const _RecentCard({required this.dest});

  final RecentDest dest;

  @override
  State<_RecentCard> createState() => _RecentCardState();
}

class _RecentCardState extends State<_RecentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.dest.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: RideBookingTheme.cardBg,
            borderRadius: BorderRadius.circular(RideBookingTheme.innerRadius),
            border: Border.all(
              color: RideBookingTheme.whiteAlpha08,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: RideBookingTheme.whiteAlpha08,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.dest.icon,
                  color: RideBookingTheme.whiteAlpha40,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dest.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: RideBookingTheme.whiteAlpha80,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.dest.address,
                      style: const TextStyle(
                        fontSize: 11,
                        color: RideBookingTheme.whiteAlpha40,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
