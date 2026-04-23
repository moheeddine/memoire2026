import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final double rating; // 0.0 – 5.0
  final int starCount;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double>? onRate; // null = read-only

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.size = 20,
    this.activeColor = const Color(0xFFFFC107),
    this.inactiveColor = Colors.white24,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (i) {
        final starValue = i + 1.0;
        final filled = rating >= starValue;
        final half = !filled && rating >= starValue - 0.5;

        return GestureDetector(
          onTap: onRate != null ? () => onRate!(starValue) : null,
          child: Icon(
            filled
                ? Icons.star
                : half
                    ? Icons.star_half
                    : Icons.star_border,
            color: (filled || half) ? activeColor : inactiveColor,
            size: size,
          ),
        );
      }),
    );
  }
}

class RatingBadge extends StatelessWidget {
  final double rating;
  final int count;
  final double starSize;

  const RatingBadge({
    super.key,
    required this.rating,
    this.count = 0,
    this.starSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarRatingWidget(rating: rating, size: starSize),
        const SizedBox(width: 4),
        Text(
          rating > 0
              ? '${rating.toStringAsFixed(1)} ($count)'
              : 'Pas encore noté',
          style: TextStyle(
            color: Colors.white54,
            fontSize: starSize - 2,
          ),
        ),
      ],
    );
  }
}
