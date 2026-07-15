import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({
    required this.rating,
    this.size = 16,
    this.showCount = false,
    this.count = 0,
    super.key,
  });

  final double rating;
  final double size;
  final bool showCount;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return Icon(Icons.star, size: size, color: Colors.amber);
          } else if (i < rating) {
            return Icon(Icons.star_half, size: size, color: Colors.amber);
          }
          return Icon(Icons.star_border, size: size, color: Colors.amber);
        }),
        if (showCount) ...[
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: TextStyle(fontSize: size * 0.8),
          ),
        ],
      ],
    );
  }
}
