import 'package:flutter/material.dart';
import 'package:delwaqty/features/ride_booking/ride_booking_theme.dart';

class SuggestedPlacesSection extends StatelessWidget {
  const SuggestedPlacesSection({
    required this.places,
    super.key,
  });

  final List<SuggestedPlace> places;

  @override
  Widget build(BuildContext context) {
    if (places.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: places.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final place = places[index];
          return _SuggestedCard(place: place);
        },
      ),
    );
  }
}

class SuggestedPlace {
  const SuggestedPlace({
    required this.name,
    required this.distance,
    required this.eta,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String distance;
  final String eta;
  final IconData icon;
  final VoidCallback onTap;
}

class _SuggestedCard extends StatefulWidget {
  const _SuggestedCard({required this.place});

  final SuggestedPlace place;

  @override
  State<_SuggestedCard> createState() => _SuggestedCardState();
}

class _SuggestedCardState extends State<_SuggestedCard>
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
        widget.place.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                RideBookingTheme.cardBg,
                RideBookingTheme.cardBg.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(RideBookingTheme.innerRadius),
            border: Border.all(
              color: RideBookingTheme.whiteAlpha08,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: RideBookingTheme.primaryPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.place.icon,
                      color: RideBookingTheme.primaryPurple,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: RideBookingTheme.whiteAlpha08,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.place.eta,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: RideBookingTheme.whiteAlpha60,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.place.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: RideBookingTheme.whiteAlpha80,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.place.distance,
                style: const TextStyle(
                  fontSize: 11,
                  color: RideBookingTheme.whiteAlpha40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
